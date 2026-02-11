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

struct ChiakiPlaceboContext {
    void *libplaceboHandle;
    void *moltenVKHandle;
    void *logHandle;
    void *vulkanHandle;
    void *rendererHandle;
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

ChiakiPlaceboContext *ChiakiPlaceboContextCreate(void) {
    struct ChiakiPlaceboContext *context = calloc(1, sizeof(struct ChiakiPlaceboContext));
    if (context == NULL) {
        return NULL;
    }
    chiakiEnsureLibraries(context);
    return context;
}

void ChiakiPlaceboContextDestroy(ChiakiPlaceboContext *context) {
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

bool ChiakiPlaceboContextIsAvailable(ChiakiPlaceboContext *context) {
    if (context == NULL) {
        return false;
    }

    return chiakiHasSymbol(context, "pl_log_create") && chiakiHasSymbol(context, "pl_renderer_create");
}

bool ChiakiPlaceboContextHasMetalObjectsExtension(ChiakiPlaceboContext *context) {
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

void *ChiakiPlaceboContextCreateLog(ChiakiPlaceboContext *context) {
    if (context == NULL || !chiakiHasSymbol(context, "pl_log_create")) {
        return NULL;
    }

    if (context->logHandle == NULL) {
        context->logHandle = chiakiCreateTokenHandle();
    }

    return context->logHandle;
}

void ChiakiPlaceboContextDestroyLog(ChiakiPlaceboContext *context) {
    if (context == NULL) {
        return;
    }

    chiakiDestroyTokenHandle(&context->logHandle);
}

void *ChiakiPlaceboContextCreateVulkanDevice(ChiakiPlaceboContext *context) {
    if (context == NULL) {
        return NULL;
    }

    if (context->logHandle == NULL) {
        (void)ChiakiPlaceboContextCreateLog(context);
    }

    if (context->logHandle == NULL || !chiakiHasSymbol(context, "vkCreateInstance")) {
        return NULL;
    }

    if (context->vulkanHandle == NULL) {
        context->vulkanHandle = chiakiCreateTokenHandle();
    }

    return context->vulkanHandle;
}

void ChiakiPlaceboContextDestroyVulkanDevice(ChiakiPlaceboContext *context) {
    if (context == NULL) {
        return;
    }

    chiakiDestroyTokenHandle(&context->vulkanHandle);
}

void *ChiakiPlaceboContextCreateRenderer(ChiakiPlaceboContext *context) {
    if (context == NULL) {
        return NULL;
    }

    if (context->vulkanHandle == NULL) {
        (void)ChiakiPlaceboContextCreateVulkanDevice(context);
    }

    if (context->vulkanHandle == NULL || !chiakiHasSymbol(context, "pl_renderer_create")) {
        return NULL;
    }

    if (context->rendererHandle == NULL) {
        context->rendererHandle = chiakiCreateTokenHandle();
    }

    return context->rendererHandle;
}

void ChiakiPlaceboContextDestroyRenderer(ChiakiPlaceboContext *context) {
    if (context == NULL) {
        return;
    }

    chiakiDestroyTokenHandle(&context->rendererHandle);
}

void *ChiakiPlaceboContextGetLog(ChiakiPlaceboContext *context) {
    return context != NULL ? context->logHandle : NULL;
}

void *ChiakiPlaceboContextGetVulkanDevice(ChiakiPlaceboContext *context) {
    return context != NULL ? context->vulkanHandle : NULL;
}

void *ChiakiPlaceboContextGetRenderer(ChiakiPlaceboContext *context) {
    return context != NULL ? context->rendererHandle : NULL;
}
