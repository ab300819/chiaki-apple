#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Directory setup
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
FRAMEWORKS_DIR="$PROJECT_ROOT/Frameworks"
BUILD_DIR="$PROJECT_ROOT/.build"

mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$BUILD_DIR"

# Common function to download and extract
download_and_extract() {
    local url=$1
    local name=$2
    local filename=$(basename "$url")
    local output_dir="$BUILD_DIR/$name"

    if [ -d "$output_dir" ]; then
        log "$name already extracted in $output_dir"
        return
    fi

    log "Downloading $name..."
    curl -L -o "$BUILD_DIR/$filename" "$url"

    log "Extracting $name..."
    mkdir -p "$output_dir"
    tar -xf "$BUILD_DIR/$filename" -C "$output_dir" --strip-components=1
}

# Common function to create XCFramework
create_xcframework() {
    local libname=$1
    local output_path="$FRAMEWORKS_DIR/$libname.xcframework"
    shift
    local inputs=("$@")

    log "Creating $libname.xcframework..."
    
    local args=""
    for input in "${inputs[@]}"; do
        args="$args -library $input -headers $(dirname $input)/../include"
    done

    rm -rf "$output_path"
    xcodebuild -create-xcframework $args -output "$output_path"
}

# Helper to configure CMake for Apple platforms
# Usage: configure_cmake <platform> <arch> <source_dir> <build_dir> <install_dir> [extra_flags...]
configure_cmake() {
    local platform=$1
    local arch=$2
    local source_dir=$3
    local build_dir=$4
    local install_dir=$5
    shift 5
    local extra_flags=("$@")

    local cmake_flags=(
        "-DCMAKE_INSTALL_PREFIX=$install_dir"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_OSX_ARCHITECTURES=$arch"
    )

    case $platform in
        "ios")
            cmake_flags+=("-DCMAKE_SYSTEM_NAME=iOS")
            cmake_flags+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=15.0")
            ;;
        "ios-simulator")
            cmake_flags+=("-DCMAKE_SYSTEM_NAME=iOS")
            cmake_flags+=("-DCMAKE_OSX_SYSROOT=iphonesimulator")
            cmake_flags+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=15.0")
            ;;
        "macos")
            cmake_flags+=("-DCMAKE_SYSTEM_NAME=Darwin")
            cmake_flags+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0")
            ;;
        "tvos")
            cmake_flags+=("-DCMAKE_SYSTEM_NAME=tvOS")
            cmake_flags+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=17.0")
            ;;
        *)
            error "Unknown platform: $platform"
            ;;
    esac

    cmake -S "$source_dir" -B "$build_dir" "${cmake_flags[@]}" "${extra_flags[@]}"
}
