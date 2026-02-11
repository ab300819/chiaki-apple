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

/// Create/destroy lifecycle owner for libplacebo bridge resources.
ChiakiPlaceboContext * _Nullable ChiakiPlaceboContextCreate(void);
void ChiakiPlaceboContextDestroy(ChiakiPlaceboContext * _Nullable context);

/// Runtime dependency checks (instance methods that reuse existing library handles).
bool ChiakiPlaceboContextIsAvailable(ChiakiPlaceboContext * _Nullable context);
bool ChiakiPlaceboContextHasMetalObjectsExtension(ChiakiPlaceboContext * _Nullable context);

/// Opaque lifecycle operations used by Swift wrappers.
void * _Nullable ChiakiPlaceboContextCreateLog(ChiakiPlaceboContext * _Nullable context);
void ChiakiPlaceboContextDestroyLog(ChiakiPlaceboContext * _Nullable context);

void * _Nullable ChiakiPlaceboContextCreateVulkanDevice(ChiakiPlaceboContext * _Nullable context);
void ChiakiPlaceboContextDestroyVulkanDevice(ChiakiPlaceboContext * _Nullable context);

void * _Nullable ChiakiPlaceboContextCreateRenderer(ChiakiPlaceboContext * _Nullable context);
void ChiakiPlaceboContextDestroyRenderer(ChiakiPlaceboContext * _Nullable context);

/// Accessors for Swift bridge diagnostics.
void * _Nullable ChiakiPlaceboContextGetLog(ChiakiPlaceboContext * _Nullable context);
void * _Nullable ChiakiPlaceboContextGetVulkanDevice(ChiakiPlaceboContext * _Nullable context);
void * _Nullable ChiakiPlaceboContextGetRenderer(ChiakiPlaceboContext * _Nullable context);

#ifdef __cplusplus
}
#endif

#endif /* PlaceboBridge_h */
