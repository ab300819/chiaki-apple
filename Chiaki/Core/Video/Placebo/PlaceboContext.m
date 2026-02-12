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

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
#include <libplacebo/vulkan.h>
#include <libplacebo/renderer.h>
#include <libplacebo/swapchain.h>
#include <libplacebo/utils/libav.h>
#endif

struct ChiakiPlaceboContext {
    void *libplaceboHandle;
    void *moltenVKHandle;
    
    // Real libplacebo objects (as pointers to avoid header dependency if missing)
    void *log;      // pl_log
    void *vulkan;   // pl_vulkan
    void *renderer; // pl_renderer
    void *swapchain;// pl_swapchain
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

static void *chiakiCreateTokenHandle(void) {
    // T-244 skeleton: token handle tracks lifecycle until full libplacebo object binding in T-245/T-246.
    return calloc(1, 1);
}

static void chiakiDestroyTokenHandle(void **handle) {
    if (handle == NULL || *handle == NULL) {
        return;
    }
    free(*handle);
    *handle = NULL;
}

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

    return chiakiHasSymbol(context, "pl_log_create") && chiakiHasSymbol(context, "pl_renderer_create");
}

bool ChiakiPlaceboContextIsRenderingReady(ChiakiPlaceboContextRef context) {
    // Returns false while WrapIOSurface and RenderFrameEx are still stubs.
    // When the real pl_render_image pipeline is implemented, change to true
    // (or perform an actual capability probe).
    (void)context;
    return false;
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
            if (strncmp(extensions[i].extensionName, "VK_EXT_metal_objects", VK_MAX_EXTENSION_NAME_SIZE) == 0) {
                found = true;
                break;
            }
        }
    }

    free(extensions);
    return found;
#else
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
        } else {
            context->log = chiakiCreateTokenHandle();
        }
#else
        context->log = chiakiCreateTokenHandle();
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
        context->log = NULL;
    } else {
        chiakiDestroyTokenHandle(&context->log);
    }
#else
    chiakiDestroyTokenHandle(&context->log);
#endif
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
        if (createFn) {
            struct pl_vulkan_params params = pl_vulkan_default_params;
            params.instance_extensions = (const char *[]) { "VK_KHR_surface", "VK_EXT_metal_surface", "VK_EXT_metal_objects" };
            params.num_instance_extensions = 3;
            context->vulkan = createFn((struct pl_log *)context->log, &params);
        } else {
            context->vulkan = chiakiCreateTokenHandle();
        }
#else
        context->vulkan = chiakiCreateTokenHandle();
#endif
    }

    return context->vulkan;
}

void ChiakiPlaceboContextDestroyVulkanDevice(ChiakiPlaceboContextRef context) {
    if (context == NULL || context->vulkan == NULL) {
        return;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    typedef void (*pl_vulkan_destroy_fn)(struct pl_vulkan **);
    pl_vulkan_destroy_fn destroyFn = (pl_vulkan_destroy_fn)dlsym(context->libplaceboHandle, "pl_vulkan_destroy");
    if (destroyFn) {
        struct pl_vulkan *plVk = (struct pl_vulkan *)context->vulkan;
        destroyFn(&plVk);
        context->vulkan = NULL;
    } else {
        chiakiDestroyTokenHandle(&context->vulkan);
    }
#else
    chiakiDestroyTokenHandle(&context->vulkan);
#endif
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
        if (createFn && context->vulkan) {
            struct pl_vulkan *vk = (struct pl_vulkan *)context->vulkan;
            context->renderer = createFn((struct pl_log *)context->log, vk->gpu);
        } else {
            context->renderer = chiakiCreateTokenHandle();
        }
#else
        context->renderer = chiakiCreateTokenHandle();
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
        context->renderer = NULL;
    } else {
        chiakiDestroyTokenHandle(&context->renderer);
    }
#else
    chiakiDestroyTokenHandle(&context->renderer);
#endif
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
    if (context == NULL || ioSurface == NULL) {
        return NULL;
    }

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    // TODO(T-247): Real implementation of VkImportMetalIOSurfaceInfoEXT
    return chiakiCreateTokenHandle();
#else
    return chiakiCreateTokenHandle();
#endif
}

void ChiakiPlaceboContextDestroyTexture(ChiakiPlaceboContextRef context, void *tex) {
    if (tex == NULL) {
        return;
    }
#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    // TODO(T-247): pl_tex_destroy when using real pl_tex objects
    free(tex);
#else
    free(tex);
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
    int width, int height,
    bool isHDR,
    const ChiakiPlaceboFrameParams *frameParams
) {
    if (context == NULL || targetSurface == NULL || srcTexY == NULL) {
        return false;
    }

    (void)srcTexUV;
    (void)width;
    (void)height;
    (void)isHDR;
    (void)frameParams;

#if CHIAKI_HAS_LIBPLACEBO_HEADERS
    // TODO(T-247): Real pl_render_image call
    return true;
#else
    return true;
#endif
}
