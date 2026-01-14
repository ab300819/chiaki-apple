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
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON" \
        "-DMBEDTLS_FATAL_WARNINGS=OFF"

    cmake --build "$build_dir" --target install
done

# Create combined directories for fat binaries
log "Creating combined libraries for multi-arch platforms..."

mkdir -p "$BUILD_DIR/mbedtls_combined_ios-simulator/lib"
mkdir -p "$BUILD_DIR/mbedtls_combined_ios-simulator/include"
cp -r "$BUILD_DIR/mbedtls_install_ios-simulator_arm64/include/"* "$BUILD_DIR/mbedtls_combined_ios-simulator/include/"

mkdir -p "$BUILD_DIR/mbedtls_combined_macos/lib"
mkdir -p "$BUILD_DIR/mbedtls_combined_macos/include"
cp -r "$BUILD_DIR/mbedtls_install_macos_arm64/include/"* "$BUILD_DIR/mbedtls_combined_macos/include/"

for lib in mbedcrypto mbedtls mbedx509; do
    lipo -create \
        "$BUILD_DIR/mbedtls_install_ios-simulator_arm64/lib/lib${lib}.a" \
        "$BUILD_DIR/mbedtls_install_ios-simulator_x86_64/lib/lib${lib}.a" \
        -output "$BUILD_DIR/mbedtls_combined_ios-simulator/lib/lib${lib}.a"

    lipo -create \
        "$BUILD_DIR/mbedtls_install_macos_arm64/lib/lib${lib}.a" \
        "$BUILD_DIR/mbedtls_install_macos_x86_64/lib/lib${lib}.a" \
        -output "$BUILD_DIR/mbedtls_combined_macos/lib/lib${lib}.a"
done

# Create XCFrameworks - only mbedcrypto includes headers (others would duplicate)
log "Creating xcframeworks..."

# mbedcrypto with headers
rm -rf "$FRAMEWORKS_DIR/mbedcrypto.xcframework"
xcodebuild -create-xcframework \
    -library "$BUILD_DIR/mbedtls_install_ios_arm64/lib/libmbedcrypto.a" -headers "$BUILD_DIR/mbedtls_install_ios_arm64/include" \
    -library "$BUILD_DIR/mbedtls_combined_ios-simulator/lib/libmbedcrypto.a" -headers "$BUILD_DIR/mbedtls_combined_ios-simulator/include" \
    -library "$BUILD_DIR/mbedtls_combined_macos/lib/libmbedcrypto.a" -headers "$BUILD_DIR/mbedtls_combined_macos/include" \
    -library "$BUILD_DIR/mbedtls_install_tvos_arm64/lib/libmbedcrypto.a" -headers "$BUILD_DIR/mbedtls_install_tvos_arm64/include" \
    -output "$FRAMEWORKS_DIR/mbedcrypto.xcframework"

# mbedtls and mbedx509 without headers (they share headers with mbedcrypto)
for lib in mbedtls mbedx509; do
    rm -rf "$FRAMEWORKS_DIR/${lib}.xcframework"
    xcodebuild -create-xcframework \
        -library "$BUILD_DIR/mbedtls_install_ios_arm64/lib/lib${lib}.a" \
        -library "$BUILD_DIR/mbedtls_combined_ios-simulator/lib/lib${lib}.a" \
        -library "$BUILD_DIR/mbedtls_combined_macos/lib/lib${lib}.a" \
        -library "$BUILD_DIR/mbedtls_install_tvos_arm64/lib/lib${lib}.a" \
        -output "$FRAMEWORKS_DIR/${lib}.xcframework"
done

log "mbedtls build complete."
