#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/build_utils.sh"

OPUS_VERSION="1.3.1"
OPUS_URL="https://archive.mozilla.org/pub/opus/opus-${OPUS_VERSION}.tar.gz"
SOURCE_DIR="$BUILD_DIR/opus-${OPUS_VERSION}"

download_and_extract "$OPUS_URL" "opus-${OPUS_VERSION}"

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
args=()
for target in "${TARGETS[@]}"; do
    read -r platform arch <<< "$target"
    install_dir="$BUILD_DIR/opus_install_${platform}_${arch}"
    args+=("$install_dir/lib/libopus.a")
done

create_xcframework "opus" "${args[@]}"

log "Opus build complete."
