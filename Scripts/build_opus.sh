#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/build_utils.sh"

OPUS_VERSION="1.3.1"
OPUS_URL="https://archive.mozilla.org/pub/opus/opus-${OPUS_VERSION}.tar.gz"
SOURCE_DIR="$BUILD_DIR/opus-${OPUS_VERSION}"

download_and_extract "$OPUS_URL" "opus-${OPUS_VERSION}"

if [ ! -f "$SOURCE_DIR/opus_buildtype.cmake" ]; then
    touch "$SOURCE_DIR/opus_buildtype.cmake"
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
    log "Building Opus for $platform ($arch)..."
    
    build_dir="$BUILD_DIR/opus_build_${platform}_${arch}"
    install_dir="$BUILD_DIR/opus_install_${platform}_${arch}"
    
    configure_cmake "$platform" "$arch" "$SOURCE_DIR" "$build_dir" "$install_dir" \
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON" \
        "-DOPUS_BUILD_PROGRAMS=OFF" \
        "-DOPUS_BUILD_TESTING=OFF" \
        "-DOPUS_BUILD_SHARED_LIBRARY=OFF"

    cmake --build "$build_dir" --target install
done

# Create XCFramework
ios_lib="$BUILD_DIR/opus_install_ios_arm64/lib/libopus.a"

mkdir -p "$BUILD_DIR/opus_combined_ios-simulator/lib"
cp -r "$BUILD_DIR/opus_install_ios-simulator_arm64/include" "$BUILD_DIR/opus_combined_ios-simulator/"
lipo -create \
    "$BUILD_DIR/opus_install_ios-simulator_arm64/lib/libopus.a" \
    "$BUILD_DIR/opus_install_ios-simulator_x86_64/lib/libopus.a" \
    -output "$BUILD_DIR/opus_combined_ios-simulator/lib/libopus.a"
ios_sim_lib="$BUILD_DIR/opus_combined_ios-simulator/lib/libopus.a"

mkdir -p "$BUILD_DIR/opus_combined_macos/lib"
cp -r "$BUILD_DIR/opus_install_macos_arm64/include" "$BUILD_DIR/opus_combined_macos/"
lipo -create \
    "$BUILD_DIR/opus_install_macos_arm64/lib/libopus.a" \
    "$BUILD_DIR/opus_install_macos_x86_64/lib/libopus.a" \
    -output "$BUILD_DIR/opus_combined_macos/lib/libopus.a"
macos_lib="$BUILD_DIR/opus_combined_macos/lib/libopus.a"

tvos_lib="$BUILD_DIR/opus_install_tvos_arm64/lib/libopus.a"

create_xcframework "opus" \
    "$ios_lib" \
    "$ios_sim_lib" \
    "$macos_lib" \
    "$tvos_lib"

log "Opus build complete."
