#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/build_utils.sh"

MBEDTLS_VERSION="2.28.0"
MBEDTLS_URL="https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v${MBEDTLS_VERSION}.tar.gz"
SOURCE_DIR="$BUILD_DIR/mbedtls-${MBEDTLS_VERSION}"

download_and_extract "$MBEDTLS_URL" "mbedtls-${MBEDTLS_VERSION}"

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
    log "Building mbedtls for $platform ($arch)..."
    
    build_dir="$BUILD_DIR/mbedtls_build_${platform}_${arch}"
    install_dir="$BUILD_DIR/mbedtls_install_${platform}_${arch}"
    
    # Enable position independent code for static libs to be linked into dynamic libs if needed (though we are building static)
    configure_cmake "$platform" "$arch" "$SOURCE_DIR" "$build_dir" "$install_dir" \
        "-DENABLE_TESTING=OFF" \
        "-DENABLE_PROGRAMS=OFF" \
        "-DUSE_SHARED_MBEDTLS_LIBRARY=OFF" \
        "-DUSE_STATIC_MBEDTLS_LIBRARY=ON" \
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"

    cmake --build "$build_dir" --target install
done

# Create XCFrameworks
LIBS=("mbedcrypto" "mbedtls" "mbedx509")

for lib in "${LIBS[@]}"; do
    args=()
    for target in "${TARGETS[@]}"; do
        read -r platform arch <<< "$target"
        install_dir="$BUILD_DIR/mbedtls_install_${platform}_${arch}"
        args+=("$install_dir/lib/lib${lib}.a")
    done
    
    create_xcframework "$lib" "${args[@]}"
done

log "mbedtls build complete."
