// SPDX-License-Identifier: AGPL-3.0-only
//
// PlaceboBridge.h
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// C bridge surface for libplacebo/Metal lifecycle management.
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

/// Returns true only when WrapIOSurface and RenderFrameEx are fully implemented
/// (not stub/token-handle mode). Used by PlaceboVideoRenderer to decide whether
/// to return nil from init and trigger Metal Native fallback.
bool ChiakiPlaceboContextIsRenderingReady(ChiakiPlaceboContextRef _Nullable context);

/// Opaque lifecycle operations used by Swift wrappers.
void * _Nullable ChiakiPlaceboContextCreateLog(ChiakiPlaceboContextRef _Nullable context);
void ChiakiPlaceboContextDestroyLog(ChiakiPlaceboContextRef _Nullable context);

void * _Nullable ChiakiPlaceboContextCreateGPU(ChiakiPlaceboContextRef _Nullable context);
void ChiakiPlaceboContextDestroyGPU(ChiakiPlaceboContextRef _Nullable context);

void * _Nullable ChiakiPlaceboContextCreateRenderer(ChiakiPlaceboContextRef _Nullable context);
void ChiakiPlaceboContextDestroyRenderer(ChiakiPlaceboContextRef _Nullable context);

/// Accessors for Swift bridge diagnostics.
void * _Nullable ChiakiPlaceboContextGetLog(ChiakiPlaceboContextRef _Nullable context);
void * _Nullable ChiakiPlaceboContextGetGPU(ChiakiPlaceboContextRef _Nullable context);
void * _Nullable ChiakiPlaceboContextGetRenderer(ChiakiPlaceboContextRef _Nullable context);

/// Blocks until all GPU operations are complete.
/// Used during teardown to ensure textures can be safely destroyed.
void ChiakiPlaceboContextGPUFinish(ChiakiPlaceboContextRef _Nullable context);

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

/// Combined upload + render pipeline that uploads from IOSurface and renders
/// in a single call on the same thread. This ensures GPU command ordering
/// (upload completes before render) and eliminates texture lifetime issues.
/// Uses pl_upload_plane with persistent texture reuse (matching chiaki-ng).
bool ChiakiPlaceboContextRenderIOSurface(
    ChiakiPlaceboContextRef _Nullable context,
    void * _Nonnull targetSurface,
    void * _Nonnull ioSurface,
    int planeCount,
    int width, int height,
    bool isHDR,
    const ChiakiPlaceboFrameParams * _Nullable frameParams
);

/// Renders an IOSurface through the same upload path into an offscreen RGBA8
/// texture and reads it back (width * height * 4 bytes). Used to verify color
/// conversion with pixel data instead of on-screen inspection.
bool ChiakiPlaceboContextRenderIOSurfaceToRGBA(
    ChiakiPlaceboContextRef _Nullable context,
    void * _Nonnull ioSurface,
    int planeCount,
    int width, int height,
    uint8_t * _Nonnull rgbaOut
);

#ifdef __cplusplus
}
#endif

#endif /* PlaceboBridge_h */
