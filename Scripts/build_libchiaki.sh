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
        "-DUPNPC_BUILD_TESTS=OFF"
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
        "-DCHIAKI_ENABLE_SETSU=OFF" \
        "-DCHIAKI_LIB_ENABLE_MBEDTLS=ON" \
        "-DCHIAKI_LIB_MBEDTLS_EXTERNAL_PROJECT=OFF" \
        "-DCHIAKI_LIB_ENABLE_OPUS=ON" \
        "-DCHIAKI_ENABLE_FFMPEG_DECODER=OFF" \
        "-DCHIAKI_USE_SYSTEM_NANOPB=OFF" \
        "-DCHIAKI_USE_SYSTEM_JERASURE=OFF" \
        "-DCHIAKI_USE_SYSTEM_CURL=OFF" \
        "-DCMAKE_PREFIX_PATH=$mbedtls_install;$opus_install;$deps_install" \
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"

    # Build only chiaki-lib target
    cmake --build "$build_dir" --target chiaki-lib
done

# Create XCFramework
args=()
headers_source=""

for target in "${TARGETS[@]}"; do
    read -r platform arch <<< "$target"
    build_dir="$BUILD_DIR/chiaki_build_${platform}_${arch}"
    lib_path="$build_dir/lib/libchiaki.a"
    
    if [ ! -f "$lib_path" ]; then
        error "libchiaki.a not found at $lib_path"
    fi
    
    # We need to specify headers for the XCFramework
    # We'll use the first build's headers as source, assuming they are identical
    if [ -z "$headers_source" ]; then
        # Create a combined headers directory
        headers_source="$BUILD_DIR/chiaki_headers"
        mkdir -p "$headers_source"
        # Copy source headers
        cp -R "$PROJECT_ROOT/chiaki-ng/lib/include/chiaki" "$headers_source/"
        # Copy generated headers (protobuf, config.h)
        # config.h is in build_dir/include/chiaki/config.h
        # protobuf headers are in build_dir/lib/protobuf... wait.
        # lib/CMakeLists.txt: target_include_directories(chiaki-lib PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/include")
        # So we should copy from build_dir/lib/include/chiaki if it exists?
        # Actually CMake configures config.h into include/chiaki/config.h in binary dir.
        cp -R "$build_dir/lib/include/chiaki" "$headers_source/"
    fi
    
    args+=("-library" "$lib_path" "-headers" "$headers_source")
done

log "Creating libchiaki.xcframework..."
rm -rf "$FRAMEWORKS_DIR/libchiaki.xcframework"
xcodebuild -create-xcframework "${args[@]}" -output "$FRAMEWORKS_DIR/libchiaki.xcframework"

log "libchiaki build complete."
