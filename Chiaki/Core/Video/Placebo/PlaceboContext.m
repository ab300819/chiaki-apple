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

#import <QuartzCore/CAMetalLayer.h>
#import <IOSurface/IOSurface.h>

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
#include <libplacebo/vulkan.h>
#include <libplacebo/renderer.h>
#include <libplacebo/swapchain.h>

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
#endif
    void *layer;
    int swapchainWidth;
    int swapchainHeight;
};

static void *chiakiOpenLibrary(const char *path) {
    if (path == NULL) {
        return NULL;
    }
    return dlopen(path, RTLD_NOW | RTLD_LOCAL);
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
    }

    if (context->moltenVKHandle == NULL) {
        context->moltenVKHandle = chiakiOpenLibrary("@rpath/MoltenVK.framework/MoltenVK");
        if (context->moltenVKHandle == NULL) {
            context->moltenVKHandle = chiakiOpenLibrary("@loader_path/../Frameworks/MoltenVK.framework/MoltenVK");
        }
    }
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

        struct pl_vulkan_swapchain_params swapchainParams = {
            .surface = context->surface,
            .present_mode = VK_PRESENT_MODE_FIFO_KHR,
            .swapchain_depth = 2,
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

void *ChiakiPlaceboContextCreateLog(ChiakiPlaceboContextRef context) {
    if (context == NULL) {
        return NULL;
    }

    if (context->log == NULL) {
#if CHIAKI_HAS_LIBPLACEBO_HEADERS
        typedef struct pl_log *(*pl_log_create_fn)(int api_ver, const struct pl_log_params *params);
        pl_log_create_fn createFn = (pl_log_create_fn)dlsym(context->libplaceboHandle, "pl_log_create");
        if (createFn) {
            context->log = createFn(PL_API_VER, NULL);
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
    typedef void (*pl_log_destroy_fn)(struct pl_log **);
    pl_log_destroy_fn destroyFn = (pl_log_destroy_fn)dlsym(context->libplaceboHandle, "pl_log_destroy");
    if (destroyFn) {
        struct pl_log *plLog = (struct pl_log *)context->log;
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
        typedef struct pl_vulkan *(*pl_vulkan_create_fn)(struct pl_log *, const struct pl_vulkan_params *);
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
            context->vulkan = createFn((struct pl_log *)context->log, &params);
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

    typedef void (*pl_vulkan_destroy_fn)(struct pl_vulkan **);
    pl_vulkan_destroy_fn destroyFn = (pl_vulkan_destroy_fn)dlsym(context->libplaceboHandle, "pl_vulkan_destroy");
    if (destroyFn) {
        struct pl_vulkan *plVk = (struct pl_vulkan *)context->vulkan;
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
        typedef struct pl_renderer *(*pl_renderer_create_fn)(struct pl_log *, struct pl_gpu *);
        pl_renderer_create_fn createFn = (pl_renderer_create_fn)dlsym(context->libplaceboHandle, "pl_renderer_create");
        if (createFn && context->vulkan && context->log) {
            struct pl_vulkan *vk = (struct pl_vulkan *)context->vulkan;
            context->renderer = createFn((struct pl_log *)context->log, vk->gpu);
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
    typedef void (*pl_renderer_destroy_fn)(struct pl_renderer **);
    pl_renderer_destroy_fn destroyFn = (pl_renderer_destroy_fn)dlsym(context->libplaceboHandle, "pl_renderer_destroy");
    if (destroyFn) {
        struct pl_renderer *plRenderer = (struct pl_renderer *)context->renderer;
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

void *ChiakiPlaceboContextWrapIOSurface(ChiakiPlaceboContextRef context, void *ioSurface, int plane) {
    if (context == NULL || ioSurface == NULL || plane < 0) {
        return NULL;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    pl_vulkan vk = (pl_vulkan)context->vulkan;
    if (vk == NULL || vk->gpu == NULL) {
        return NULL;
    }

    IOSurfaceRef surface = (__bridge IOSurfaceRef)ioSurface;
    size_t planeCount = IOSurfaceGetPlaneCount(surface);
    size_t planeIndex = (size_t)plane;

    if (planeCount > 0 && planeIndex >= planeCount) {
        return NULL;
    }

    IOReturn lockErr = IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
    if (lockErr != kIOReturnSuccess) {
        return NULL;
    }

    size_t width = planeCount > 0 ? IOSurfaceGetWidthOfPlane(surface, planeIndex) : IOSurfaceGetWidth(surface);
    size_t height = planeCount > 0 ? IOSurfaceGetHeightOfPlane(surface, planeIndex) : IOSurfaceGetHeight(surface);
    size_t rowBytes = planeCount > 0 ? IOSurfaceGetBytesPerRowOfPlane(surface, planeIndex) : IOSurfaceGetBytesPerRow(surface);
    void *baseAddress = planeCount > 0 ? IOSurfaceGetBaseAddressOfPlane(surface, planeIndex) : IOSurfaceGetBaseAddress(surface);

    if (width == 0 || height == 0 || rowBytes == 0 || baseAddress == NULL) {
        IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
        return NULL;
    }

    int components = (planeIndex == 0) ? 1 : 2;
    pl_fmt fmt = pl_find_fmt(vk->gpu, PL_FMT_UNORM, components, 8, 8, PL_FMT_CAP_SAMPLEABLE);
    if (fmt == NULL) {
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

    struct pl_color_space hint = isHDR ? pl_color_space_hdr10 : pl_color_space_bt709;
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

    image.repr = pl_color_repr_hdtv;
    image.color = isHDR ? pl_color_space_hdr10 : pl_color_space_bt709;
    image.crop = (pl_rect2df){
        .x0 = 0.0f,
        .y0 = 0.0f,
        .x1 = (float)width,
        .y1 = (float)height,
    };

    struct pl_frame target = {0};
    pl_frame_from_swapchain(&target, &swFrame);

    const struct pl_render_params *baseParams = &pl_render_default_params;
    if (frameParams != NULL) {
        switch (frameParams->preset) {
            case CHIAKI_PLACEBO_RENDER_PRESET_PERFORMANCE:
                baseParams = &pl_render_fast_params;
                break;
            case CHIAKI_PLACEBO_RENDER_PRESET_HIGH_QUALITY:
                baseParams = &pl_render_high_quality_params;
                break;
            case CHIAKI_PLACEBO_RENDER_PRESET_DEFAULT:
            default:
                baseParams = &pl_render_default_params;
                break;
        }
    }

    struct pl_render_params renderParams = *baseParams;
    struct pl_color_adjustment adjustment = pl_color_adjustment_neutral;
    if (frameParams != NULL) {
        adjustment.brightness = frameParams->adjustment.brightness;
        adjustment.contrast = frameParams->adjustment.contrast;
        adjustment.saturation = frameParams->adjustment.saturation;
        renderParams.color_adjustment = &adjustment;

        if (frameParams->deband.enabled) {
            struct pl_deband_params deband = pl_deband_default_params;
            deband.iterations = (int)frameParams->deband.iterations;
            deband.threshold = frameParams->deband.threshold;
            deband.radius = frameParams->deband.radius;
            deband.grain = frameParams->deband.grain;
            renderParams.deband_params = &deband;

            bool ok = pl_render_image((pl_renderer)context->renderer, &image, &target, &renderParams);
            bool submitOk = pl_swapchain_submit_frame(swapchain);
            pl_swapchain_swap_buffers(swapchain);
            return ok && submitOk;
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
