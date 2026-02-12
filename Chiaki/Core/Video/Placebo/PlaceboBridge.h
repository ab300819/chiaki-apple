// SPDX-License-Identifier: AGPL-3.0-only
//
// PlaceboBridge.h
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// C bridge surface for libplacebo/Vulkan lifecycle management.
//
// @requirement F-042 - libplacebo 渲染后端集成
// @satisfies AC-173 - PlaceboVideoRenderer 协议实现（桥接前置）

#ifndef PlaceboBridge_h
#define PlaceboBridge_h

#include <stdbool.h>
#include <stdint.h>

#if __has_include(<libplacebo/log.h>)
#include <libplacebo/log.h>
#define CHIAKI_HAS_LIBPLACEBO_HEADERS 1
#else
#define CHIAKI_HAS_LIBPLACEBO_HEADERS 0
#endif

#if __has_include(<vulkan/vulkan.h>)
#include <vulkan/vulkan.h>
#define CHIAKI_HAS_VULKAN_HEADERS 1
#else
#define CHIAKI_HAS_VULKAN_HEADERS 0
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ChiakiPlaceboContext ChiakiPlaceboContext;
typedef ChiakiPlaceboContext * ChiakiPlaceboContextRef;

typedef enum {
    CHIAKI_PLACEBO_RENDER_PRESET_PERFORMANCE = 0,
    CHIAKI_PLACEBO_RENDER_PRESET_DEFAULT = 1,
    CHIAKI_PLACEBO_RENDER_PRESET_HIGH_QUALITY = 2,
} ChiakiPlaceboRenderPreset;

typedef enum {
    CHIAKI_PLACEBO_UPSCALER_BILINEAR = 0,
    CHIAKI_PLACEBO_UPSCALER_LANCZOS = 1,
    CHIAKI_PLACEBO_UPSCALER_EWA_LANCZOSSHARP = 2,
} ChiakiPlaceboUpscaler;

typedef struct {
    bool enabled;
    uint32_t iterations;
    float threshold;
    float radius;
    float grain;
} ChiakiPlaceboDebandParams;

typedef struct {
    float brightness;
    float contrast;
    float saturation;
} ChiakiPlaceboColorAdjustment;

typedef struct {
    ChiakiPlaceboRenderPreset preset;
    ChiakiPlaceboUpscaler upscaler;
    bool tonemapEnabled;
    float targetMaxLuma;
    uint32_t colorSpace;
    ChiakiPlaceboDebandParams deband;
    ChiakiPlaceboColorAdjustment adjustment;
} ChiakiPlaceboFrameParams;

/// Create/destroy lifecycle owner for libplacebo bridge resources.
ChiakiPlaceboContextRef _Nullable ChiakiPlaceboContextCreate(void);
void ChiakiPlaceboContextDestroy(ChiakiPlaceboContextRef _Nullable context);

/// Runtime dependency checks (instance methods that reuse existing library handles).
bool ChiakiPlaceboContextIsAvailable(ChiakiPlaceboContextRef _Nullable context);
bool ChiakiPlaceboContextHasMetalObjectsExtension(ChiakiPlaceboContextRef _Nullable context);

/// Opaque lifecycle operations used by Swift wrappers.
void * _Nullable ChiakiPlaceboContextCreateLog(ChiakiPlaceboContextRef _Nullable context);
void ChiakiPlaceboContextDestroyLog(ChiakiPlaceboContextRef _Nullable context);

void * _Nullable ChiakiPlaceboContextCreateVulkanDevice(ChiakiPlaceboContextRef _Nullable context);
void ChiakiPlaceboContextDestroyVulkanDevice(ChiakiPlaceboContextRef _Nullable context);

void * _Nullable ChiakiPlaceboContextCreateRenderer(ChiakiPlaceboContextRef _Nullable context);
void ChiakiPlaceboContextDestroyRenderer(ChiakiPlaceboContextRef _Nullable context);

/// Accessors for Swift bridge diagnostics.
void * _Nullable ChiakiPlaceboContextGetLog(ChiakiPlaceboContextRef _Nullable context);
void * _Nullable ChiakiPlaceboContextGetVulkanDevice(ChiakiPlaceboContextRef _Nullable context);
void * _Nullable ChiakiPlaceboContextGetRenderer(ChiakiPlaceboContextRef _Nullable context);

/// Texture import and rendering pipeline (T-246)
/// Wraps an IOSurface from CVPixelBuffer into a libplacebo texture (pl_tex).
void * _Nullable ChiakiPlaceboContextWrapIOSurface(ChiakiPlaceboContextRef _Nullable context, void * _Nonnull ioSurface, int plane);

/// Destroys a texture previously created by WrapIOSurface.
void ChiakiPlaceboContextDestroyTexture(ChiakiPlaceboContextRef _Nullable context, void * _Nullable tex);

/// Executes the libplacebo rendering pipeline.
bool ChiakiPlaceboContextRenderFrame(
    ChiakiPlaceboContextRef _Nullable context,
    void * _Nonnull targetSurface, // CAMetalLayer or VkSurfaceKHR handle
    void * _Nonnull srcTexY,
    void * _Nullable srcTexUV,
    int width, int height,
    bool isHDR
);

bool ChiakiPlaceboContextRenderFrameEx(
    ChiakiPlaceboContextRef _Nullable context,
    void * _Nonnull targetSurface,
    void * _Nonnull srcTexY,
    void * _Nullable srcTexUV,
    int width, int height,
    bool isHDR,
    const ChiakiPlaceboFrameParams * _Nullable frameParams
);

#ifdef __cplusplus
}
#endif

#endif /* PlaceboBridge_h */
