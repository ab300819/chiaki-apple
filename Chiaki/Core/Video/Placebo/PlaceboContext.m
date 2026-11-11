// SPDX-License-Identifier: AGPL-3.0-only
//
// PlaceboContext.m
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// C bridge lifecycle layer for libplacebo/Vulkan resources.
//
// @requirement F-042 - libplacebo 渲染后端集成
// @satisfies AC-173 - PlaceboVideoRenderer 协议实现（桥接前置）

#include "PlaceboBridge.h"

#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>
#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
#include <libplacebo/vulkan.h>
#include <libplacebo/renderer.h>
#include <libplacebo/swapchain.h>
#include <libplacebo/utils/upload.h>

#ifndef VK_EXT_METAL_SURFACE_EXTENSION_NAME
#define VK_EXT_METAL_SURFACE_EXTENSION_NAME "VK_EXT_metal_surface"
#endif

#ifndef VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT
#define VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT ((VkStructureType)1000217000)
#endif

#ifndef VK_EXT_METAL_OBJECTS_EXTENSION_NAME
#define VK_EXT_METAL_OBJECTS_EXTENSION_NAME "VK_EXT_metal_objects"
#endif

#ifndef VK_MVK_MACOS_SURFACE_EXTENSION_NAME
#define VK_MVK_MACOS_SURFACE_EXTENSION_NAME "VK_MVK_macos_surface"
#endif

#ifndef VK_KHR_SWAPCHAIN_EXTENSION_NAME
#define VK_KHR_SWAPCHAIN_EXTENSION_NAME "VK_KHR_swapchain"
#endif

#ifndef VK_KHR_SURFACE_EXTENSION_NAME
#define VK_KHR_SURFACE_EXTENSION_NAME "VK_KHR_surface"
#endif

typedef VkFlags VkMetalSurfaceCreateFlagsEXT;
typedef struct VkMetalSurfaceCreateInfoEXT {
    VkStructureType sType;
    const void *pNext;
    VkMetalSurfaceCreateFlagsEXT flags;
    const void *pLayer;
} VkMetalSurfaceCreateInfoEXT;

typedef VkResult (VKAPI_PTR *PFN_chiakiVkCreateMetalSurfaceEXT)(
    VkInstance instance,
    const VkMetalSurfaceCreateInfoEXT *pCreateInfo,
    const VkAllocationCallbacks *pAllocator,
    VkSurfaceKHR *pSurface
);
#endif

struct ChiakiPlaceboContext {
    void *libplaceboHandle;
    void *moltenVKHandle;

    // libplacebo objects
    void *log;      // pl_log
    void *vulkan;   // pl_vulkan
    void *renderer; // pl_renderer
    void *swapchain;// pl_swapchain

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    VkSurfaceKHR surface;
    // Persistent textures reused by pl_upload_plane across frames.
    // pl_upload_plane recreates them only when dimensions/format change.
    pl_tex uploadTex[4];
#endif
    void *layer;
    int swapchainWidth;
    int swapchainHeight;
};

static void *chiakiOpenLibrary(const char *path) {
    if (path == NULL) {
        return NULL;
    }
    void *handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        const char *err = dlerror();
        NSLog(@"[placebo] dlopen failed for %s: %s", path, err != NULL ? err : "unknown");
    }
    return handle;
}

static void *chiakiOpenFrameworkFromBundle(NSString *frameworkName, NSString *binaryName) {
    NSString *frameworksPath = [[NSBundle mainBundle] privateFrameworksPath];
    if (frameworksPath.length == 0) {
        return NULL;
    }

    NSString *rootBinary = [[frameworksPath stringByAppendingPathComponent:[frameworkName stringByAppendingString:@".framework"]]
        stringByAppendingPathComponent:binaryName];
    void *handle = chiakiOpenLibrary(rootBinary.fileSystemRepresentation);
    if (handle != NULL) {
        return handle;
    }

    NSString *versionedBinary = [[[[frameworksPath stringByAppendingPathComponent:[frameworkName stringByAppendingString:@".framework"]]
        stringByAppendingPathComponent:@"Versions"] stringByAppendingPathComponent:@"A"] stringByAppendingPathComponent:binaryName];
    return chiakiOpenLibrary(versionedBinary.fileSystemRepresentation);
}

static void chiakiEnsureLibraries(struct ChiakiPlaceboContext *context) {
    if (context == NULL) {
        return;
    }

    if (context->libplaceboHandle == NULL) {
        context->libplaceboHandle = chiakiOpenLibrary("@rpath/libplacebo.framework/libplacebo");
        if (context->libplaceboHandle == NULL) {
            context->libplaceboHandle = chiakiOpenLibrary("@loader_path/../Frameworks/libplacebo.framework/libplacebo");
        }
        if (context->libplaceboHandle == NULL) {
            context->libplaceboHandle = chiakiOpenLibrary("@executable_path/../Frameworks/libplacebo.framework/libplacebo");
        }
        if (context->libplaceboHandle == NULL) {
            context->libplaceboHandle = chiakiOpenFrameworkFromBundle(@"libplacebo", @"libplacebo");
        }
    }

    if (context->moltenVKHandle == NULL) {
        context->moltenVKHandle = chiakiOpenLibrary("@rpath/MoltenVK.framework/MoltenVK");
        if (context->moltenVKHandle == NULL) {
            context->moltenVKHandle = chiakiOpenLibrary("@loader_path/../Frameworks/MoltenVK.framework/MoltenVK");
        }
        if (context->moltenVKHandle == NULL) {
            context->moltenVKHandle = chiakiOpenLibrary("@executable_path/../Frameworks/MoltenVK.framework/MoltenVK");
        }
        if (context->moltenVKHandle == NULL) {
            context->moltenVKHandle = chiakiOpenFrameworkFromBundle(@"MoltenVK", @"MoltenVK");
        }
    }

    NSLog(@"[placebo] library handles: libplacebo=%p moltenvk=%p", context->libplaceboHandle, context->moltenVKHandle);
}

static bool chiakiHasSymbol(struct ChiakiPlaceboContext *context, const char *symbol) {
    if (symbol == NULL) {
        return false;
    }

    if (dlsym(RTLD_DEFAULT, symbol) != NULL) {
        return true;
    }

    if (context == NULL) {
        return false;
    }

    chiakiEnsureLibraries(context);

    if (context->libplaceboHandle != NULL && dlsym(context->libplaceboHandle, symbol) != NULL) {
        return true;
    }

    if (context->moltenVKHandle != NULL && dlsym(context->moltenVKHandle, symbol) != NULL) {
        return true;
    }

    // libplacebo may version some exported symbols (e.g. pl_log_create_349).
    if (strcmp(symbol, "pl_log_create") == 0) {
        if (dlsym(RTLD_DEFAULT, "pl_log_create_349") != NULL) {
            return true;
        }
        if (context->libplaceboHandle != NULL && dlsym(context->libplaceboHandle, "pl_log_create_349") != NULL) {
            return true;
        }
    }

    return false;
}

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
static pl_vulkan chiakiGetVulkan(struct ChiakiPlaceboContext *context) {
    return context != NULL ? (pl_vulkan)context->vulkan : NULL;
}

static PFN_vkDestroySurfaceKHR chiakiGetDestroySurfaceFn(struct ChiakiPlaceboContext *context, pl_vulkan vk) {
    if (context == NULL || vk == NULL || vk->get_proc_addr == NULL) {
        return NULL;
    }

    PFN_vkDestroySurfaceKHR fn =
        (PFN_vkDestroySurfaceKHR)vk->get_proc_addr(vk->instance, "vkDestroySurfaceKHR");
    if (fn != NULL) {
        return fn;
    }

    if (context->moltenVKHandle != NULL) {
        fn = (PFN_vkDestroySurfaceKHR)dlsym(context->moltenVKHandle, "vkDestroySurfaceKHR");
    }
    return fn;
}

static PFN_chiakiVkCreateMetalSurfaceEXT chiakiGetCreateMetalSurfaceFn(struct ChiakiPlaceboContext *context, pl_vulkan vk) {
    if (context == NULL || vk == NULL || vk->get_proc_addr == NULL) {
        return NULL;
    }

    PFN_chiakiVkCreateMetalSurfaceEXT fn =
        (PFN_chiakiVkCreateMetalSurfaceEXT)vk->get_proc_addr(vk->instance, "vkCreateMetalSurfaceEXT");
    if (fn != NULL) {
        return fn;
    }

    if (context->moltenVKHandle != NULL) {
        fn = (PFN_chiakiVkCreateMetalSurfaceEXT)dlsym(context->moltenVKHandle, "vkCreateMetalSurfaceEXT");
    }
    return fn;
}

static void chiakiDestroySwapchain(struct ChiakiPlaceboContext *context) {
    if (context == NULL) {
        return;
    }

    if (context->swapchain != NULL) {
        pl_swapchain sw = (pl_swapchain)context->swapchain;
        pl_swapchain_destroy(&sw);
        context->swapchain = NULL;
    }

    pl_vulkan vk = chiakiGetVulkan(context);
    if (context->surface != VK_NULL_HANDLE && vk != NULL) {
        PFN_vkDestroySurfaceKHR destroyFn = chiakiGetDestroySurfaceFn(context, vk);
        if (destroyFn != NULL) {
            destroyFn(vk->instance, context->surface, NULL);
        }
        context->surface = VK_NULL_HANDLE;
    }

    context->layer = NULL;
    context->swapchainWidth = 0;
    context->swapchainHeight = 0;
}

static bool chiakiEnsureSwapchain(
    struct ChiakiPlaceboContext *context,
    CAMetalLayer *layer,
    int width,
    int height
) {
    if (context == NULL || context->vulkan == NULL || layer == nil) {
        return false;
    }

    pl_vulkan vk = (pl_vulkan)context->vulkan;

    if (context->swapchain != NULL && context->layer != (__bridge void *)layer) {
        chiakiDestroySwapchain(context);
    }

    if (context->swapchain == NULL) {
        PFN_chiakiVkCreateMetalSurfaceEXT createSurfaceFn = chiakiGetCreateMetalSurfaceFn(context, vk);
        if (createSurfaceFn == NULL) {
            return false;
        }

        VkMetalSurfaceCreateInfoEXT surfaceInfo = {
            .sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT,
            .pNext = NULL,
            .flags = 0,
            .pLayer = (__bridge const void *)layer,
        };

        VkResult err = createSurfaceFn(vk->instance, &surfaceInfo, NULL, &context->surface);
        if (err != VK_SUCCESS || context->surface == VK_NULL_HANDLE) {
            return false;
        }

        // BUG-027: Use swapchain_depth = 1 (matching chiaki-ng upstream).
        // With depth 1, swap_buffers blocks until the previous frame's GPU
        // commands complete, making single-frame deferred texture destruction
        // safe. Depth 2 caused texture use-after-free because swap_buffers
        // didn't guarantee the N-1th frame was done.
        struct pl_vulkan_swapchain_params swapchainParams = {
            .surface = context->surface,
            .present_mode = VK_PRESENT_MODE_FIFO_KHR,
            .swapchain_depth = 1,
        };

        pl_swapchain sw = pl_vulkan_create_swapchain(vk, &swapchainParams);
        if (sw == NULL) {
            chiakiDestroySwapchain(context);
            return false;
        }

        context->swapchain = (void *)sw;
        context->layer = (__bridge void *)layer;
    }

    pl_swapchain sw = (pl_swapchain)context->swapchain;
    int resizeW = width;
    int resizeH = height;
    if (resizeW <= 0 || resizeH <= 0) {
        return false;
    }

    if (resizeW != context->swapchainWidth || resizeH != context->swapchainHeight) {
        if (!pl_swapchain_resize(sw, &resizeW, &resizeH)) {
            return false;
        }
        context->swapchainWidth = resizeW;
        context->swapchainHeight = resizeH;
    }

    return true;
}
#endif

ChiakiPlaceboContextRef ChiakiPlaceboContextCreate(void) {
    struct ChiakiPlaceboContext *context = calloc(1, sizeof(struct ChiakiPlaceboContext));
    if (context == NULL) {
        return NULL;
    }
    chiakiEnsureLibraries(context);
    return context;
}

void ChiakiPlaceboContextDestroy(ChiakiPlaceboContextRef context) {
    if (context == NULL) {
        return;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    // Destroy persistent upload textures before swapchain/device teardown
    if (context->vulkan != NULL) {
        pl_vulkan vk = (pl_vulkan)context->vulkan;
        for (int i = 0; i < 4; i++) {
            pl_tex_destroy(vk->gpu, &context->uploadTex[i]);
        }
    }
    chiakiDestroySwapchain(context);
#endif
    ChiakiPlaceboContextDestroyRenderer(context);
    ChiakiPlaceboContextDestroyVulkanDevice(context);
    ChiakiPlaceboContextDestroyLog(context);

    if (context->libplaceboHandle != NULL) {
        dlclose(context->libplaceboHandle);
        context->libplaceboHandle = NULL;
    }

    if (context->moltenVKHandle != NULL) {
        dlclose(context->moltenVKHandle);
        context->moltenVKHandle = NULL;
    }

    free(context);
}

bool ChiakiPlaceboContextIsAvailable(ChiakiPlaceboContextRef context) {
    if (context == NULL) {
        return false;
    }

    return chiakiHasSymbol(context, "pl_log_create") &&
           chiakiHasSymbol(context, "pl_renderer_create") &&
           chiakiHasSymbol(context, "pl_vulkan_create");
}

bool ChiakiPlaceboContextIsRenderingReady(ChiakiPlaceboContextRef context) {
#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    if (context == NULL) {
        return false;
    }

    return chiakiHasSymbol(context, "pl_render_image") &&
           chiakiHasSymbol(context, "pl_swapchain_start_frame") &&
           chiakiHasSymbol(context, "pl_vulkan_create_swapchain") &&
           chiakiHasSymbol(context, "pl_tex_create");
#else
    (void)context;
    return false;
#endif
}

bool ChiakiPlaceboContextHasMetalObjectsExtension(ChiakiPlaceboContextRef context) {
#if CHIAKI_HAS_VULKAN_HEADERS
    if (context == NULL || !chiakiHasSymbol(context, "vkEnumerateInstanceExtensionProperties")) {
        return false;
    }

    PFN_vkEnumerateInstanceExtensionProperties enumerateFn =
        (PFN_vkEnumerateInstanceExtensionProperties)dlsym(RTLD_DEFAULT, "vkEnumerateInstanceExtensionProperties");

    if (enumerateFn == NULL && context->moltenVKHandle != NULL) {
        enumerateFn = (PFN_vkEnumerateInstanceExtensionProperties)dlsym(context->moltenVKHandle, "vkEnumerateInstanceExtensionProperties");
    }

    if (enumerateFn == NULL) {
        return false;
    }

    uint32_t count = 0;
    VkResult result = enumerateFn(NULL, &count, NULL);
    if (result != VK_SUCCESS || count == 0) {
        return false;
    }

    VkExtensionProperties *extensions = calloc(count, sizeof(VkExtensionProperties));
    if (extensions == NULL) {
        return false;
    }

    result = enumerateFn(NULL, &count, extensions);
    bool found = false;

    if (result == VK_SUCCESS) {
        for (uint32_t i = 0; i < count; i++) {
            if (strncmp(extensions[i].extensionName, VK_EXT_METAL_OBJECTS_EXTENSION_NAME, VK_MAX_EXTENSION_NAME_SIZE) == 0) {
                found = true;
                break;
            }
        }
    }

    free(extensions);
    return found;
#else
    (void)context;
    return false;
#endif
}

static void chiakiPlaceboLogCallback(void *priv, enum pl_log_level level, const char *msg) {
    (void)priv;
    static const char *levelNames[] = {
        "NONE", "FATAL", "ERR", "WARN", "INFO", "DEBUG", "TRACE"
    };
    int idx = (int)level;
    if (idx < 0 || idx > 6) idx = 0;
    NSLog(@"[libplacebo:%s] %s", levelNames[idx], msg);
}

void *ChiakiPlaceboContextCreateLog(ChiakiPlaceboContextRef context) {
    if (context == NULL) {
        return NULL;
    }

    if (context->log == NULL) {
#if CHIAKI_HAS_LIBPLACEBO_HEADERS
        typedef pl_log (*pl_log_create_fn)(int api_ver, const struct pl_log_params *params);
        pl_log_create_fn createFn = (pl_log_create_fn)dlsym(context->libplaceboHandle, "pl_log_create");
        if (createFn == NULL) {
            createFn = (pl_log_create_fn)dlsym(context->libplaceboHandle, "pl_log_create_349");
        }
        if (createFn) {
            struct pl_log_params logParams = {
                .log_cb = chiakiPlaceboLogCallback,
                .log_priv = NULL,
                .log_level = PL_LOG_INFO,
            };
            context->log = (void *)createFn(PL_API_VER, &logParams);
        }
#else
        context->log = NULL;
#endif
    }

    return context->log;
}

void ChiakiPlaceboContextDestroyLog(ChiakiPlaceboContextRef context) {
    if (context == NULL || context->log == NULL) {
        return;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    typedef void (*pl_log_destroy_fn)(pl_log *);
    pl_log_destroy_fn destroyFn = (pl_log_destroy_fn)dlsym(context->libplaceboHandle, "pl_log_destroy");
    if (destroyFn) {
        pl_log plLog = (pl_log)context->log;
        destroyFn(&plLog);
    }
#endif
    context->log = NULL;
}

void *ChiakiPlaceboContextCreateVulkanDevice(ChiakiPlaceboContextRef context) {
    if (context == NULL) {
        return NULL;
    }

    if (context->log == NULL) {
        (void)ChiakiPlaceboContextCreateLog(context);
    }

    if (context->vulkan == NULL) {
#if CHIAKI_HAS_LIBPLACEBO_HEADERS
        typedef pl_vulkan (*pl_vulkan_create_fn)(pl_log, const struct pl_vulkan_params *);
        pl_vulkan_create_fn createFn = (pl_vulkan_create_fn)dlsym(context->libplaceboHandle, "pl_vulkan_create");
        if (createFn && context->log) {
            static const char *requiredInstanceExts[] = {
                VK_KHR_SURFACE_EXTENSION_NAME,
                VK_EXT_METAL_SURFACE_EXTENSION_NAME,
            };
            static const char *optionalInstanceExts[] = {
                VK_EXT_METAL_OBJECTS_EXTENSION_NAME,
                VK_MVK_MACOS_SURFACE_EXTENSION_NAME,
            };
            static const char *deviceExts[] = {
                VK_KHR_SWAPCHAIN_EXTENSION_NAME,
            };

            struct pl_vk_inst_params instParams = pl_vk_inst_default_params;
            instParams.extensions = requiredInstanceExts;
            instParams.num_extensions = (int)(sizeof(requiredInstanceExts) / sizeof(requiredInstanceExts[0]));
            instParams.opt_extensions = optionalInstanceExts;
            instParams.num_opt_extensions = (int)(sizeof(optionalInstanceExts) / sizeof(optionalInstanceExts[0]));

            struct pl_vulkan_params params = pl_vulkan_default_params;
            params.instance_params = &instParams;
            params.extensions = deviceExts;
            params.num_extensions = (int)(sizeof(deviceExts) / sizeof(deviceExts[0]));
            params.get_proc_addr = (PFN_vkGetInstanceProcAddr)dlsym(RTLD_DEFAULT, "vkGetInstanceProcAddr");
            if (params.get_proc_addr == NULL && context->moltenVKHandle != NULL) {
                params.get_proc_addr = (PFN_vkGetInstanceProcAddr)dlsym(context->moltenVKHandle, "vkGetInstanceProcAddr");
            }
            context->vulkan = (void *)createFn((pl_log)context->log, &params);
        }
#endif
    }

    return context->vulkan;
}

void ChiakiPlaceboContextDestroyVulkanDevice(ChiakiPlaceboContextRef context) {
    if (context == NULL || context->vulkan == NULL) {
        return;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    chiakiDestroySwapchain(context);

    typedef void (*pl_vulkan_destroy_fn)(pl_vulkan *);
    pl_vulkan_destroy_fn destroyFn = (pl_vulkan_destroy_fn)dlsym(context->libplaceboHandle, "pl_vulkan_destroy");
    if (destroyFn) {
        pl_vulkan plVk = (pl_vulkan)context->vulkan;
        destroyFn(&plVk);
    }
#endif
    context->vulkan = NULL;
}

void *ChiakiPlaceboContextCreateRenderer(ChiakiPlaceboContextRef context) {
    if (context == NULL) {
        return NULL;
    }

    if (context->vulkan == NULL) {
        (void)ChiakiPlaceboContextCreateVulkanDevice(context);
    }

    if (context->renderer == NULL) {
#if CHIAKI_HAS_LIBPLACEBO_HEADERS
        typedef pl_renderer (*pl_renderer_create_fn)(pl_log, pl_gpu);
        pl_renderer_create_fn createFn = (pl_renderer_create_fn)dlsym(context->libplaceboHandle, "pl_renderer_create");
        if (createFn && context->vulkan && context->log) {
            pl_vulkan vk = (pl_vulkan)context->vulkan;
            context->renderer = (void *)createFn((pl_log)context->log, vk->gpu);
        }
#endif
    }

    return context->renderer;
}

void ChiakiPlaceboContextDestroyRenderer(ChiakiPlaceboContextRef context) {
    if (context == NULL || context->renderer == NULL) {
        return;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    typedef void (*pl_renderer_destroy_fn)(pl_renderer *);
    pl_renderer_destroy_fn destroyFn = (pl_renderer_destroy_fn)dlsym(context->libplaceboHandle, "pl_renderer_destroy");
    if (destroyFn) {
        pl_renderer plRenderer = (pl_renderer)context->renderer;
        destroyFn(&plRenderer);
    }
#endif
    context->renderer = NULL;
}

void *ChiakiPlaceboContextGetLog(ChiakiPlaceboContextRef context) {
    return context != NULL ? context->log : NULL;
}

void *ChiakiPlaceboContextGetVulkanDevice(ChiakiPlaceboContextRef context) {
    return context != NULL ? context->vulkan : NULL;
}

void *ChiakiPlaceboContextGetRenderer(ChiakiPlaceboContextRef context) {
    return context != NULL ? context->renderer : NULL;
}

void ChiakiPlaceboContextGPUFinish(ChiakiPlaceboContextRef context) {
    if (context == NULL || context->vulkan == NULL) {
        return;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    pl_vulkan vk = (pl_vulkan)context->vulkan;
    if (vk->gpu != NULL) {
        pl_gpu_finish(vk->gpu);
    }
#endif
}

void *ChiakiPlaceboContextWrapIOSurface(ChiakiPlaceboContextRef context, void *ioSurface, int plane) {
    if (context == NULL || ioSurface == NULL || plane < 0) {
        return NULL;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    pl_vulkan vk = (pl_vulkan)context->vulkan;
    if (vk == NULL || vk->gpu == NULL) {
        return NULL;
    }

    IOSurfaceRef surface = (IOSurfaceRef)ioSurface;
    size_t planeCount = IOSurfaceGetPlaneCount(surface);
    size_t planeIndex = (size_t)plane;

    if (planeCount > 0 && planeIndex >= planeCount) {
        return NULL;
    }

    size_t width = planeCount > 0 ? IOSurfaceGetWidthOfPlane(surface, planeIndex) : IOSurfaceGetWidth(surface);
    size_t height = planeCount > 0 ? IOSurfaceGetHeightOfPlane(surface, planeIndex) : IOSurfaceGetHeight(surface);

    if (width == 0 || height == 0) {
        return NULL;
    }

    int components = (planeIndex == 0) ? 1 : 2;
    pl_fmt fmt = pl_find_fmt(vk->gpu, PL_FMT_UNORM, components, 8, 8, PL_FMT_CAP_SAMPLEABLE);
    if (fmt == NULL) {
        NSLog(@"[placebo] WrapIOSurface plane=%d: no matching format for %d components", plane, components);
        return NULL;
    }

    // CPU staging buffer upload: lock IOSurface, copy pixel data, unlock.
    // Note: Zero-copy import via PL_HANDLE_MTL_TEX was attempted but removed
    // because ARC released the MTLTexture while MoltenVK command buffers still
    // referenced it, causing Metal validation failures. The upload path copies
    // data into a libplacebo-owned texture, avoiding lifetime issues.
    size_t rowBytes = planeCount > 0 ? IOSurfaceGetBytesPerRowOfPlane(surface, planeIndex) : IOSurfaceGetBytesPerRow(surface);

    IOReturn lockErr = IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
    if (lockErr != kIOReturnSuccess) {
        return NULL;
    }

    void *baseAddress = planeCount > 0 ? IOSurfaceGetBaseAddressOfPlane(surface, planeIndex) : IOSurfaceGetBaseAddress(surface);

    if (rowBytes == 0 || baseAddress == NULL) {
        IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
        return NULL;
    }

    pl_tex tex = pl_tex_create(vk->gpu, pl_tex_params(
        .w = (int)width,
        .h = (int)height,
        .format = fmt,
        .sampleable = true,
        .host_writable = true
    ));

    if (tex == NULL) {
        IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
        return NULL;
    }

    struct pl_tex_transfer_params upload = {
        .tex = tex,
        .row_pitch = rowBytes,
        .ptr = baseAddress,
    };

    bool uploaded = pl_tex_upload(vk->gpu, &upload);
    IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);

    if (!uploaded) {
        pl_tex_destroy(vk->gpu, &tex);
        return NULL;
    }

    return (void *)tex;
#else
    (void)context;
    (void)ioSurface;
    (void)plane;
    return NULL;
#endif
}

void ChiakiPlaceboContextDestroyTexture(ChiakiPlaceboContextRef context, void *tex) {
    if (tex == NULL) {
        return;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    if (context != NULL && context->vulkan != NULL) {
        pl_vulkan vk = (pl_vulkan)context->vulkan;
        pl_tex plTex = (pl_tex)tex;
        pl_tex_destroy(vk->gpu, &plTex);
        return;
    }
#endif
}

bool ChiakiPlaceboContextRenderFrame(
    ChiakiPlaceboContextRef context,
    void *targetSurface,
    void *srcTexY,
    void *srcTexUV,
    int width, int height,
    bool isHDR
) {
    return ChiakiPlaceboContextRenderFrameEx(
        context,
        targetSurface,
        srcTexY,
        srcTexUV,
        width,
        height,
        isHDR,
        NULL
    );
}

bool ChiakiPlaceboContextRenderFrameEx(
    ChiakiPlaceboContextRef context,
    void *targetSurface,
    void *srcTexY,
    void *srcTexUV,
    int width,
    int height,
    bool isHDR,
    const ChiakiPlaceboFrameParams *frameParams
) {
    if (context == NULL || targetSurface == NULL || srcTexY == NULL || width <= 0 || height <= 0) {
        return false;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    if (context->renderer == NULL) {
        return false;
    }

    CAMetalLayer *layer = (__bridge CAMetalLayer *)targetSurface;
    if (layer == nil) {
        return false;
    }

    CGSize drawableSize = layer.drawableSize;
    int targetWidth = (int)drawableSize.width;
    int targetHeight = (int)drawableSize.height;
    if (targetWidth <= 0 || targetHeight <= 0) {
        targetWidth = width;
        targetHeight = height;
    }

    if (!chiakiEnsureSwapchain(context, layer, targetWidth, targetHeight)) {
        return false;
    }

    pl_swapchain swapchain = (pl_swapchain)context->swapchain;
    if (swapchain == NULL) {
        return false;
    }

    // BUG-027: Use manually-initialized color structs instead of extern const
    // symbols (pl_color_repr_hdtv, pl_color_space_bt709, etc.). These extern
    // const data symbols may resolve to zeroed memory when the framework is
    // loaded via dlopen with RTLD_LOCAL. When pl_color_repr.sys == 0
    // (PL_COLOR_SYSTEM_UNKNOWN), libplacebo skips YCbCr→RGB conversion,
    // causing garbled blue/green output.
    static bool diagnosticLogged = false;
    if (!diagnosticLogged) {
        diagnosticLogged = true;
        NSLog(@"[placebo] RenderFrameEx extern const diagnostics:");
        NSLog(@"[placebo]   pl_color_repr_hdtv.sys = %d (expected %d = PL_COLOR_SYSTEM_BT_709)",
              (int)pl_color_repr_hdtv.sys, (int)PL_COLOR_SYSTEM_BT_709);
        NSLog(@"[placebo]   pl_color_space_bt709.primaries = %d (expected %d = PL_COLOR_PRIM_BT_709)",
              (int)pl_color_space_bt709.primaries, (int)PL_COLOR_PRIM_BT_709);
        NSLog(@"[placebo]   pl_color_space_bt709.transfer = %d (expected %d = PL_COLOR_TRC_BT_1886)",
              (int)pl_color_space_bt709.transfer, (int)PL_COLOR_TRC_BT_1886);
        void *reprSym = dlsym(RTLD_DEFAULT, "pl_color_repr_hdtv");
        void *reprSymLib = context->libplaceboHandle ? dlsym(context->libplaceboHandle, "pl_color_repr_hdtv") : NULL;
        NSLog(@"[placebo]   dlsym(RTLD_DEFAULT, pl_color_repr_hdtv) = %p", reprSym);
        NSLog(@"[placebo]   dlsym(libplacebo, pl_color_repr_hdtv) = %p", reprSymLib);
        NSLog(@"[placebo]   &pl_color_repr_hdtv = %p", &pl_color_repr_hdtv);
        if (reprSym != NULL) {
            NSLog(@"[placebo]   dlsym resolved .sys = %d",
                  (int)((const struct pl_color_repr *)reprSym)->sys);
        }
    }

    struct pl_color_space colorSpaceBT709 = {
        .primaries = PL_COLOR_PRIM_BT_709,
        .transfer = PL_COLOR_TRC_BT_1886,
    };
    struct pl_color_space colorSpaceHDR10 = {
        .primaries = PL_COLOR_PRIM_BT_2020,
        .transfer = PL_COLOR_TRC_PQ,
    };

    struct pl_color_space hint = isHDR ? colorSpaceHDR10 : colorSpaceBT709;
    pl_swapchain_colorspace_hint(swapchain, &hint);

    struct pl_swapchain_frame swFrame = {0};
    if (!pl_swapchain_start_frame(swapchain, &swFrame)) {
        return false;
    }

    struct pl_frame image = {0};
    image.num_planes = srcTexUV != NULL ? 2 : 1;

    image.planes[0].texture = (pl_tex)srcTexY;
    image.planes[0].components = 1;
    image.planes[0].component_mapping[0] = 0;
    image.planes[0].component_mapping[1] = -1;
    image.planes[0].component_mapping[2] = -1;
    image.planes[0].component_mapping[3] = -1;

    if (srcTexUV != NULL) {
        image.planes[1].texture = (pl_tex)srcTexUV;
        image.planes[1].components = 2;
        image.planes[1].component_mapping[0] = 1;
        image.planes[1].component_mapping[1] = 2;
        image.planes[1].component_mapping[2] = -1;
        image.planes[1].component_mapping[3] = -1;
        pl_chroma_location_offset(PL_CHROMA_LEFT, &image.planes[1].shift_x, &image.planes[1].shift_y);
    }

    image.repr = (struct pl_color_repr) {
        .sys = PL_COLOR_SYSTEM_BT_709,
        .levels = PL_COLOR_LEVELS_TV,
    };
    image.color = isHDR ? colorSpaceHDR10 : colorSpaceBT709;
    image.crop = (pl_rect2df){
        .x0 = 0.0f,
        .y0 = 0.0f,
        .x1 = (float)width,
        .y1 = (float)height,
    };

    struct pl_frame target = {0};
    pl_frame_from_swapchain(&target, &swFrame);

    // Resolve render params via dlsym to avoid extern const linkage issues.
    const struct pl_render_params *baseParams = NULL;
    if (frameParams != NULL) {
        switch (frameParams->preset) {
            case CHIAKI_PLACEBO_RENDER_PRESET_PERFORMANCE:
                baseParams = (const struct pl_render_params *)dlsym(
                    context->libplaceboHandle, "pl_render_fast_params");
                break;
            case CHIAKI_PLACEBO_RENDER_PRESET_HIGH_QUALITY:
                baseParams = (const struct pl_render_params *)dlsym(
                    context->libplaceboHandle, "pl_render_high_quality_params");
                break;
            case CHIAKI_PLACEBO_RENDER_PRESET_DEFAULT:
            default:
                break;
        }
    }
    if (baseParams == NULL) {
        baseParams = (const struct pl_render_params *)dlsym(
            context->libplaceboHandle, "pl_render_default_params");
    }
    if (baseParams == NULL) {
        baseParams = (const struct pl_render_params *)dlsym(
            RTLD_DEFAULT, "pl_render_default_params");
    }
    if (baseParams == NULL) {
        // Ultimate fallback: zero-initialized params (basic rendering)
        static const struct pl_render_params fallbackParams = {0};
        baseParams = &fallbackParams;
        NSLog(@"[placebo] WARNING: could not resolve pl_render_default_params via dlsym, using zero params");
    }

    struct pl_render_params renderParams = *baseParams;

    // Manual neutral values instead of pl_color_adjustment_neutral extern const
    struct pl_color_adjustment adjustment = {
        .brightness = 0.0f,
        .contrast = 1.0f,
        .saturation = 1.0f,
        .hue = 0.0f,
        .gamma = 1.0f,
        .temperature = 0.0f,
    };

    // Deband params storage in outer scope so pointer stays valid for pl_render_image
    struct pl_deband_params debandStorage = {0};

    if (frameParams != NULL) {
        adjustment.brightness = frameParams->adjustment.brightness;
        adjustment.contrast = frameParams->adjustment.contrast;
        adjustment.saturation = frameParams->adjustment.saturation;
        renderParams.color_adjustment = &adjustment;

        if (frameParams->deband.enabled) {
            debandStorage.iterations = (int)frameParams->deband.iterations;
            debandStorage.threshold = frameParams->deband.threshold;
            debandStorage.radius = frameParams->deband.radius;
            debandStorage.grain = frameParams->deband.grain;
            renderParams.deband_params = &debandStorage;
        }
    }

    bool ok = pl_render_image((pl_renderer)context->renderer, &image, &target, &renderParams);
    bool submitOk = pl_swapchain_submit_frame(swapchain);
    pl_swapchain_swap_buffers(swapchain);
    return ok && submitOk;
#else
    (void)targetSurface;
    (void)srcTexY;
    (void)srcTexUV;
    (void)width;
    (void)height;
    (void)isHDR;
    (void)frameParams;
    return false;
#endif
}

bool ChiakiPlaceboContextRenderIOSurface(
    ChiakiPlaceboContextRef context,
    void *targetSurface,
    void *ioSurface,
    int planeCount,
    int width, int height,
    bool isHDR,
    const ChiakiPlaceboFrameParams *frameParams
) {
    if (context == NULL || targetSurface == NULL || ioSurface == NULL ||
        width <= 0 || height <= 0 || planeCount < 1) {
        return false;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    if (context->renderer == NULL || context->vulkan == NULL) {
        return false;
    }

    pl_vulkan vk = (pl_vulkan)context->vulkan;
    if (vk->gpu == NULL) {
        return false;
    }

    CAMetalLayer *layer = (__bridge CAMetalLayer *)targetSurface;
    if (layer == nil) {
        return false;
    }

    CGSize drawableSize = layer.drawableSize;
    int targetWidth = (int)drawableSize.width;
    int targetHeight = (int)drawableSize.height;
    if (targetWidth <= 0 || targetHeight <= 0) {
        targetWidth = width;
        targetHeight = height;
    }

    if (!chiakiEnsureSwapchain(context, layer, targetWidth, targetHeight)) {
        return false;
    }

    pl_swapchain swapchain = (pl_swapchain)context->swapchain;
    if (swapchain == NULL) {
        return false;
    }

    // --- Lock IOSurface and upload planes ---
    IOSurfaceRef surface = (IOSurfaceRef)ioSurface;
    IOReturn lockErr = IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
    if (lockErr != kIOReturnSuccess) {
        return false;
    }

    // Diagnostic: log IOSurface details on first frame
    static bool iosDiagLogged = false;
    if (!iosDiagLogged) {
        iosDiagLogged = true;
        OSType pixFmt = IOSurfaceGetPixelFormat(surface);
        char fcc[5] = {
            (char)((pixFmt >> 24) & 0xFF),
            (char)((pixFmt >> 16) & 0xFF),
            (char)((pixFmt >> 8) & 0xFF),
            (char)(pixFmt & 0xFF),
            0
        };
        NSLog(@"[placebo] IOSurface diagnostic:");
        NSLog(@"[placebo]   pixelFormat = 0x%08x ('%s')", (unsigned)pixFmt, fcc);
        NSLog(@"[placebo]   totalSize = %zu", IOSurfaceGetAllocSize(surface));
        NSLog(@"[placebo]   planeCount = %zu", IOSurfaceGetPlaneCount(surface));
        for (size_t dp = 0; dp < IOSurfaceGetPlaneCount(surface) && dp < 4; dp++) {
            size_t pw = IOSurfaceGetWidthOfPlane(surface, dp);
            size_t ph = IOSurfaceGetHeightOfPlane(surface, dp);
            size_t pr = IOSurfaceGetBytesPerRowOfPlane(surface, dp);
            size_t pe = IOSurfaceGetBytesPerElementOfPlane(surface, dp);
            void *pa = IOSurfaceGetBaseAddressOfPlane(surface, dp);
            NSLog(@"[placebo]   plane[%zu]: %zux%zu stride=%zu elemSize=%zu addr=%p",
                  dp, pw, ph, pr, pe, pa);
            // Dump first 32 bytes of each plane
            if (pa != NULL && pr > 0) {
                const uint8_t *bytes = (const uint8_t *)pa;
                NSLog(@"[placebo]   plane[%zu] first 32 bytes: "
                      "%02x %02x %02x %02x %02x %02x %02x %02x "
                      "%02x %02x %02x %02x %02x %02x %02x %02x "
                      "%02x %02x %02x %02x %02x %02x %02x %02x "
                      "%02x %02x %02x %02x %02x %02x %02x %02x",
                      dp,
                      bytes[0], bytes[1], bytes[2], bytes[3],
                      bytes[4], bytes[5], bytes[6], bytes[7],
                      bytes[8], bytes[9], bytes[10], bytes[11],
                      bytes[12], bytes[13], bytes[14], bytes[15],
                      bytes[16], bytes[17], bytes[18], bytes[19],
                      bytes[20], bytes[21], bytes[22], bytes[23],
                      bytes[24], bytes[25], bytes[26], bytes[27],
                      bytes[28], bytes[29], bytes[30], bytes[31]);
                // Also dump bytes at row midpoint to check for tiling
                size_t midOff = pr * (ph / 2);
                const uint8_t *mid = bytes + midOff;
                NSLog(@"[placebo]   plane[%zu] mid-frame 16 bytes (row %zu): "
                      "%02x %02x %02x %02x %02x %02x %02x %02x "
                      "%02x %02x %02x %02x %02x %02x %02x %02x",
                      dp, ph / 2,
                      mid[0], mid[1], mid[2], mid[3],
                      mid[4], mid[5], mid[6], mid[7],
                      mid[8], mid[9], mid[10], mid[11],
                      mid[12], mid[13], mid[14], mid[15]);
            }
        }
    }

    struct pl_frame image = {0};
    image.num_planes = planeCount > 1 ? 2 : 1;
    bool uploadOk = true;

    // --- DIAGNOSTIC: Synthetic NV12 test pattern ---
    // Set to 1 to replace IOSurface data with a known-good green color bar.
    // If the synthetic pattern renders correctly, the pipeline works and
    // the issue is with IOSurface data access on Apple Silicon.
#define PLACEBO_SYNTHETIC_TEST 0
#if PLACEBO_SYNTHETIC_TEST
    // BT.709 TV-range green: Y=145, Cb=54, Cr=34
    static uint8_t *synthY = NULL;
    static uint8_t *synthUV = NULL;
    if (synthY == NULL) {
        synthY = malloc(width * height);
        memset(synthY, 145, width * height); // Y = 145 (bright green luma)
        synthUV = malloc(width * (height / 2));
        for (int i = 0; i < width * (height / 2); i += 2) {
            synthUV[i] = 54;   // Cb (green has low Cb)
            synthUV[i+1] = 34; // Cr (green has low Cr)
        }
        NSLog(@"[placebo] SYNTHETIC TEST: using green test pattern instead of IOSurface data");
    }
#endif

    for (int p = 0; p < image.num_planes; p++) {
        size_t planeW, planeH;
        if (planeCount > 1) {
            planeW = IOSurfaceGetWidthOfPlane(surface, (size_t)p);
            planeH = IOSurfaceGetHeightOfPlane(surface, (size_t)p);
        } else {
            planeW = IOSurfaceGetWidth(surface);
            planeH = IOSurfaceGetHeight(surface);
        }

        if (planeW == 0 || planeH == 0) {
            uploadOk = false;
            break;
        }

        void *baseAddress;
        size_t rowBytes;
        if (planeCount > 1) {
            baseAddress = IOSurfaceGetBaseAddressOfPlane(surface, (size_t)p);
            rowBytes = IOSurfaceGetBytesPerRowOfPlane(surface, (size_t)p);
        } else {
            baseAddress = IOSurfaceGetBaseAddress(surface);
            rowBytes = IOSurfaceGetBytesPerRow(surface);
        }

        if (baseAddress == NULL || rowBytes == 0) {
            uploadOk = false;
            break;
        }

#if PLACEBO_SYNTHETIC_TEST
        // Override with synthetic data (tightly packed, no padding)
        if (p == 0) {
            baseAddress = synthY;
            rowBytes = (size_t)width;
        } else {
            baseAddress = synthUV;
            rowBytes = (size_t)width; // CbCr: 2 bytes per pixel pair, width/2 pairs = width bytes
        }
#endif

        // Set up pl_plane_data for this plane (NV12: plane 0 = Y, plane 1 = CbCr)
        struct pl_plane_data data = {0};
        data.type = PL_FMT_UNORM;
        data.width = (int)planeW;
        data.height = (int)planeH;
        data.row_stride = rowBytes;
        data.pixels = baseAddress;

        if (p == 0) {
            // Y plane: single 8-bit component
            data.component_size[0] = 8;
            data.component_pad[0] = 0;
            data.component_map[0] = PL_CHANNEL_Y;
            data.pixel_stride = 1;
        } else {
            // CbCr plane: two interleaved 8-bit components
            data.component_size[0] = 8;
            data.component_size[1] = 8;
            data.component_pad[0] = 0;
            data.component_pad[1] = 0;
            data.component_map[0] = PL_CHANNEL_CB;
            data.component_map[1] = PL_CHANNEL_CR;
            data.pixel_stride = 2;
        }

        // pl_upload_plane handles format finding, texture creation/reuse, upload,
        // and populates image.planes[p] with correct component_mapping.
        if (!pl_upload_plane(vk->gpu, &image.planes[p], &context->uploadTex[p], &data)) {
            NSLog(@"[placebo] pl_upload_plane failed for plane %d (%dx%d stride=%zu)",
                  p, (int)planeW, (int)planeH, rowBytes);
            uploadOk = false;
            break;
        }

        // Diagnostic: log pl_upload_plane results on first frame
        static bool uploadDiagLogged = false;
        if (!uploadDiagLogged && p == image.num_planes - 1) {
            uploadDiagLogged = true;
            for (int dp = 0; dp < image.num_planes; dp++) {
                NSLog(@"[placebo] pl_upload_plane result plane[%d]: "
                      "tex=%p components=%d mapping=[%d,%d,%d,%d]",
                      dp, (void *)image.planes[dp].texture,
                      image.planes[dp].components,
                      image.planes[dp].component_mapping[0],
                      image.planes[dp].component_mapping[1],
                      image.planes[dp].component_mapping[2],
                      image.planes[dp].component_mapping[3]);
            }
        }
    }

    IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);

    if (!uploadOk) {
        return false;
    }

    // Set chroma location for subsampled UV plane (matching chiaki-ng)
    if (image.num_planes > 1) {
        pl_frame_set_chroma_location(&image, PL_CHROMA_LEFT);
    }

    // --- Set up color metadata ---
    struct pl_color_space colorSpaceBT709 = {
        .primaries = PL_COLOR_PRIM_BT_709,
        .transfer = PL_COLOR_TRC_BT_1886,
    };
    struct pl_color_space colorSpaceHDR10 = {
        .primaries = PL_COLOR_PRIM_BT_2020,
        .transfer = PL_COLOR_TRC_PQ,
    };

    image.repr = (struct pl_color_repr) {
        .sys = PL_COLOR_SYSTEM_BT_709,
        .levels = PL_COLOR_LEVELS_TV,
        .bits = {
            .sample_depth = 8,
            .color_depth = 8,
            .bit_shift = 0,
        },
    };
    image.color = isHDR ? colorSpaceHDR10 : colorSpaceBT709;
    image.crop = (pl_rect2df){
        .x0 = 0.0f,
        .y0 = 0.0f,
        .x1 = (float)width,
        .y1 = (float)height,
    };

    // --- Swapchain + render ---
    struct pl_color_space hint = isHDR ? colorSpaceHDR10 : colorSpaceBT709;
    pl_swapchain_colorspace_hint(swapchain, &hint);

    struct pl_swapchain_frame swFrame = {0};
    if (!pl_swapchain_start_frame(swapchain, &swFrame)) {
        return false;
    }

    struct pl_frame target = {0};
    pl_frame_from_swapchain(&target, &swFrame);

    // Resolve render params
    const struct pl_render_params *baseParams = NULL;
    if (frameParams != NULL) {
        switch (frameParams->preset) {
            case CHIAKI_PLACEBO_RENDER_PRESET_PERFORMANCE:
                baseParams = (const struct pl_render_params *)dlsym(
                    context->libplaceboHandle, "pl_render_fast_params");
                break;
            case CHIAKI_PLACEBO_RENDER_PRESET_HIGH_QUALITY:
                baseParams = (const struct pl_render_params *)dlsym(
                    context->libplaceboHandle, "pl_render_high_quality_params");
                break;
            default:
                break;
        }
    }
    if (baseParams == NULL) {
        baseParams = (const struct pl_render_params *)dlsym(
            context->libplaceboHandle, "pl_render_default_params");
    }
    if (baseParams == NULL) {
        baseParams = (const struct pl_render_params *)dlsym(
            RTLD_DEFAULT, "pl_render_default_params");
    }
    if (baseParams == NULL) {
        static const struct pl_render_params fallbackParams = {0};
        baseParams = &fallbackParams;
    }

    struct pl_render_params renderParams = *baseParams;
    struct pl_color_adjustment adjustment = {
        .brightness = 0.0f,
        .contrast = 1.0f,
        .saturation = 1.0f,
        .hue = 0.0f,
        .gamma = 1.0f,
        .temperature = 0.0f,
    };
    struct pl_deband_params debandStorage = {0};

    if (frameParams != NULL) {
        adjustment.brightness = frameParams->adjustment.brightness;
        adjustment.contrast = frameParams->adjustment.contrast;
        adjustment.saturation = frameParams->adjustment.saturation;
        renderParams.color_adjustment = &adjustment;

        if (frameParams->deband.enabled) {
            debandStorage.iterations = (int)frameParams->deband.iterations;
            debandStorage.threshold = frameParams->deband.threshold;
            debandStorage.radius = frameParams->deband.radius;
            debandStorage.grain = frameParams->deband.grain;
            renderParams.deband_params = &debandStorage;
        }
    }

    bool ok = pl_render_image((pl_renderer)context->renderer, &image, &target, &renderParams);
    bool submitOk = pl_swapchain_submit_frame(swapchain);
    pl_swapchain_swap_buffers(swapchain);
    return ok && submitOk;
#else
    (void)targetSurface;
    (void)ioSurface;
    (void)planeCount;
    (void)width;
    (void)height;
    (void)isHDR;
    (void)frameParams;
    return false;
#endif
}
