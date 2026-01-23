#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/build_utils.sh"

JSONC_VERSION="0.16"
JSONC_URL="https://s3.amazonaws.com/json-c_releases/releases/json-c-${JSONC_VERSION}.tar.gz"
MINIUPNPC_VERSION="2.2.3"
MINIUPNPC_URL="http://miniupnp.free.fr/files/miniupnpc-${MINIUPNPC_VERSION}.tar.gz"

download_and_extract "$JSONC_URL" "json-c-${JSONC_VERSION}"
download_and_extract "$MINIUPNPC_URL" "miniupnpc-${MINIUPNPC_VERSION}"

miniuppnc_cmake="$BUILD_DIR/miniupnpc-${MINIUPNPC_VERSION}/CMakeLists.txt"
if ! grep -q "include/miniupnpc.h" "$miniuppnc_cmake"; then
    sed -i '' 's|[[:space:]]miniupnpc.h| include/miniupnpc.h|g' "$miniuppnc_cmake"
    sed -i '' 's|[[:space:]]miniwget.h| include/miniwget.h|g' "$miniuppnc_cmake"
    sed -i '' 's|[[:space:]]upnpcommands.h| include/upnpcommands.h|g' "$miniuppnc_cmake"
    sed -i '' 's|[[:space:]]igd_desc_parse.h| include/igd_desc_parse.h|g' "$miniuppnc_cmake"
    sed -i '' 's|[[:space:]]upnpreplyparse.h| include/upnpreplyparse.h|g' "$miniuppnc_cmake"
    sed -i '' 's|[[:space:]]upnperrors.h| include/upnperrors.h|g' "$miniuppnc_cmake"
    sed -i '' 's|[[:space:]]upnpdev.h| include/upnpdev.h|g' "$miniuppnc_cmake"
    sed -i '' 's|[[:space:]]miniupnpctypes.h| include/miniupnpctypes.h|g' "$miniuppnc_cmake"
    sed -i '' 's|[[:space:]]portlistingparse.h| include/portlistingparse.h|g' "$miniuppnc_cmake"
    sed -i '' 's|[[:space:]]miniupnpc_declspec.h| include/miniupnpc_declspec.h|g' "$miniuppnc_cmake"
fi

# Apply patches to chiaki-ng
PATCHES_DIR="$PROJECT_ROOT/Patches"
if [ -d "$PATCHES_DIR" ]; then
    pushd "$PROJECT_ROOT/chiaki-ng" > /dev/null
    for patch in "$PATCHES_DIR"/*.patch; do
        if [ -f "$patch" ]; then
            patch_name=$(basename "$patch")
            # Check if patch can be applied (not already applied)
            if git apply --check "$patch" 2>/dev/null; then
                log "Applying patch: $patch_name"
                git apply "$patch"
            else
                # Check if patch is already applied by trying reverse
                if git apply --check -R "$patch" 2>/dev/null; then
                    log "Patch already applied: $patch_name"
                else
                    log "Warning: Patch not applicable: $patch_name"
                fi
            fi
        fi
    done
    popd > /dev/null
fi

# Define targets
# Format: platform arch
TARGETS=(
    "ios arm64"
    "ios-simulator arm64"
    "ios-simulator x86_64"
    "macos arm64"
    "macos x86_64"
    "tvos arm64"
)

# Build for each target
for target in "${TARGETS[@]}"; do
    read -r platform arch <<< "$target"
    log "Building Dependencies and libchiaki for $platform ($arch)..."
    
    # Paths
    mbedtls_install="$BUILD_DIR/mbedtls_install_${platform}_${arch}"
    opus_install="$BUILD_DIR/opus_install_${platform}_${arch}"
    deps_install="$BUILD_DIR/deps_install_${platform}_${arch}"
    
    # Check if mbedtls/opus exist
    if [ ! -d "$mbedtls_install" ] || [ ! -d "$opus_install" ]; then
        error "mbedtls or opus build not found for $platform $arch. Run build_mbedtls.sh and build_opus.sh first."
    fi

    # Ensure submodules are initialized
    if [ -z "$(ls -A "$PROJECT_ROOT/chiaki-ng/third-party/nanopb")" ]; then
        log "Initializing chiaki-ng submodules..."
        pushd "$PROJECT_ROOT/chiaki-ng" > /dev/null
        git submodule update --init --recursive
        popd > /dev/null
    fi

    # 1. Build json-c
    log "Building json-c..."
    configure_cmake "$platform" "$arch" "$BUILD_DIR/json-c-${JSONC_VERSION}" \
        "$BUILD_DIR/jsonc_build_${platform}_${arch}" "$deps_install" \
        "-DBUILD_SHARED_LIBS=OFF" \
        "-DBUILD_TESTING=OFF"
    cmake --build "$BUILD_DIR/jsonc_build_${platform}_${arch}" --target install

    # 2. Build miniupnpc
    log "Building miniupnpc..."
    configure_cmake "$platform" "$arch" "$BUILD_DIR/miniupnpc-${MINIUPNPC_VERSION}" \
        "$BUILD_DIR/miniupnpc_build_${platform}_${arch}" "$deps_install" \
        "-DUPNPC_BUILD_SHARED=OFF" \
        "-DUPNPC_BUILD_TESTS=OFF" \
        "-DCMAKE_C_FLAGS=-D_DARWIN_C_SOURCE"
    cmake --build "$BUILD_DIR/miniupnpc_build_${platform}_${arch}" --target install

    # 3. Build libchiaki
    log "Building libchiaki..."

    # Set PKG_CONFIG_PATH for json-c and miniupnpc
    export PKG_CONFIG_PATH="$deps_install/lib/pkgconfig:$deps_install/share/pkgconfig"
    
    build_dir="$BUILD_DIR/chiaki_build_${platform}_${arch}"
    # We install to a temp dir to collect headers/libs easily if chiaki supports install, 
    # but chiaki-lib target might not have install rules in lib/CMakeLists.txt?
    # Checking lib/CMakeLists.txt... it doesn't seem to have install(TARGETS...)
    # So we will just pick the .a file from build_dir/lib/
    
    # We need to pass paths to mbedtls and opus
    # We use CMAKE_PREFIX_PATH
    
    configure_cmake "$platform" "$arch" "$PROJECT_ROOT/chiaki-ng" "$build_dir" "$deps_install" \
        "-DCHIAKI_ENABLE_CLI=OFF" \
        "-DCHIAKI_ENABLE_GUI=OFF" \
        "-DCHIAKI_ENABLE_TESTS=OFF" \
        "-DCHIAKI_ENABLE_ANDROID=OFF" \
        "-DCHIAKI_ENABLE_BOREALIS=OFF" \
        "-DCHIAKI_ENABLE_STEAMDECK_NATIVE=OFF" \
        "-DCHIAKI_ENABLE_STEAM_SHORTCUT=OFF" \
        "-DCHIAKI_ENABLE_SETSU=OFF" \
        "-DCHIAKI_ENABLE_SPEEX=OFF" \
        "-DCHIAKI_ENABLE_RUDP=OFF" \
        "-DCHIAKI_LIB_ENABLE_MBEDTLS=ON" \
        "-DCHIAKI_LIB_MBEDTLS_EXTERNAL_PROJECT=OFF" \
        "-DCHIAKI_LIB_ENABLE_OPUS=ON" \
        "-DCHIAKI_ENABLE_FFMPEG_DECODER=OFF" \
        "-DCHIAKI_ENABLE_PI_DECODER=OFF" \
        "-DCHIAKI_USE_SYSTEM_NANOPB=OFF" \
        "-DCHIAKI_USE_SYSTEM_JERASURE=OFF" \
        "-DCHIAKI_USE_SYSTEM_CURL=OFF" \
        "-DCURL_USE_MBEDTLS=ON" \
        "-DCURL_USE_OPENSSL=OFF" \
        "-DUSE_NGHTTP2=OFF" \
        "-DUSE_LIBIDN2=OFF" \
        "-DCURL_USE_LIBSSH2=OFF" \
        "-DCMAKE_PREFIX_PATH=$mbedtls_install;$opus_install;$deps_install" \
        "-DCMAKE_FIND_ROOT_PATH=$mbedtls_install;$opus_install;$deps_install" \
        "-DOpus_INCLUDE_DIRS=$opus_install/include" \
        "-DOpus_LIBRARIES=$opus_install/lib/libopus.a" \
        "-DCMAKE_C_FLAGS=-I$mbedtls_install/include -DGESTALT_WORKAROUND=1" \
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"

    # Build only chiaki-lib target
    cmake --build "$build_dir" --target chiaki-lib
done

# Merge all static libraries for each platform
merge_libs() {
    local platform=$1
    local arch=$2
    local output=$3

    local chiaki_build="$BUILD_DIR/chiaki_build_${platform}_${arch}"
    local deps_install="$BUILD_DIR/deps_install_${platform}_${arch}"

    # Collect all .a files (chiaki + third-party + external deps)
    local libs=(
        "$chiaki_build/lib/libchiaki.a"
        "$chiaki_build/third-party/nanopb/libprotobuf-nanopb.a"
        "$chiaki_build/third-party/curl/lib/libcurl.a"
        "$chiaki_build/third-party/libjerasure.a"
        "$chiaki_build/third-party/libgf_complete.a"
        "$deps_install/lib/libjson-c.a"
        "$deps_install/lib/libminiupnpc.a"
    )

    log "Merging libraries for $platform $arch..."
    libtool -static -o "$output" "${libs[@]}"
}

log "Merging static libraries for each platform..."

# Merge for single-arch platforms
merge_libs "ios" "arm64" "$BUILD_DIR/libchiaki_merged_ios_arm64.a"
merge_libs "ios-simulator" "arm64" "$BUILD_DIR/libchiaki_merged_ios-simulator_arm64.a"
merge_libs "ios-simulator" "x86_64" "$BUILD_DIR/libchiaki_merged_ios-simulator_x86_64.a"
merge_libs "macos" "arm64" "$BUILD_DIR/libchiaki_merged_macos_arm64.a"
merge_libs "macos" "x86_64" "$BUILD_DIR/libchiaki_merged_macos_x86_64.a"
merge_libs "tvos" "arm64" "$BUILD_DIR/libchiaki_merged_tvos_arm64.a"

# Create XCFramework
log "Creating libchiaki.xcframework..."

headers_source="$BUILD_DIR/chiaki_headers"
mkdir -p "$headers_source"
cp -R "$PROJECT_ROOT/chiaki-ng/lib/include/chiaki" "$headers_source/"
cp -R "$BUILD_DIR/chiaki_build_ios_arm64/lib/include/chiaki" "$headers_source/"

# Copy mbedtls headers for Swift/C struct layout compatibility
# Without this, ChiakiECDH has different size in Swift vs C due to conditional compilation
log "Copying mbedtls headers for Swift compatibility..."
cp -R "$BUILD_DIR/mbedtls-2.28.0/include/mbedtls" "$headers_source/chiaki/"

# Update config.h to define CHIAKI_LIB_ENABLE_MBEDTLS for Swift
# This ensures struct layouts match between Swift and C
log "Updating config.h with CHIAKI_LIB_ENABLE_MBEDTLS..."
cat > "$headers_source/chiaki/config.h" << 'EOF'
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#ifndef CHIAKI_CONFIG_H
#define CHIAKI_CONFIG_H

#define CHIAKI_LIB_ENABLE_OPUS 1
#define CHIAKI_LIB_ENABLE_PI_DECODER 0
#define CHIAKI_LIB_ENABLE_MBEDTLS 1

#endif // CHIAKI_CONFIG_H
EOF

ios_lib="$BUILD_DIR/libchiaki_merged_ios_arm64.a"

mkdir -p "$BUILD_DIR/chiaki_combined_ios-simulator"
lipo -create \
    "$BUILD_DIR/libchiaki_merged_ios-simulator_arm64.a" \
    "$BUILD_DIR/libchiaki_merged_ios-simulator_x86_64.a" \
    -output "$BUILD_DIR/chiaki_combined_ios-simulator/libchiaki.a"
ios_sim_lib="$BUILD_DIR/chiaki_combined_ios-simulator/libchiaki.a"

mkdir -p "$BUILD_DIR/chiaki_combined_macos"
lipo -create \
    "$BUILD_DIR/libchiaki_merged_macos_arm64.a" \
    "$BUILD_DIR/libchiaki_merged_macos_x86_64.a" \
    -output "$BUILD_DIR/chiaki_combined_macos/libchiaki.a"
macos_lib="$BUILD_DIR/chiaki_combined_macos/libchiaki.a"

tvos_lib="$BUILD_DIR/libchiaki_merged_tvos_arm64.a"

rm -rf "$FRAMEWORKS_DIR/libchiaki.xcframework"
xcodebuild -create-xcframework \
    -library "$ios_lib" -headers "$headers_source" \
    -library "$ios_sim_lib" -headers "$headers_source" \
    -library "$macos_lib" -headers "$headers_source" \
    -library "$tvos_lib" -headers "$headers_source" \
    -output "$FRAMEWORKS_DIR/libchiaki.xcframework"

log "libchiaki build complete."
