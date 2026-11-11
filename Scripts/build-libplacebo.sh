#!/bin/bash
set -euo pipefail

# @requirement F-042 - libplacebo 渲染后端集成
# @satisfies AC-171 - 预编译 xcframework 集成
# @satisfies AC-172 - 动态 framework 链接

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/build_utils.sh"

# libplacebo fork with the native Metal backend (upstream has none yet).
# metal-absorb only fast-forwards (no force push), so pinning a SHA is stable.
LIBPLACEBO_REPO="https://github.com/ab300819/libplacebo.git"
LIBPLACEBO_COMMIT="ba3cd3da6e8a7210c543ede69c8a68f5cf37ecc2"
MACOS_MIN="15.0"

LIBPLACEBO_SRC_DIR="$BUILD_DIR/libplacebo-src"
OUT_LIBPLACEBO_XCF="$FRAMEWORKS_DIR/libplacebo.xcframework"

usage() {
    cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --clean                      Remove prior libplacebo build artifacts first
  -h, --help                   Show this help

Notes:
  - Builds macOS arm64 only. The Metal backend needs an Apple7+ GPU (M1 or
    later), so an x86_64 slice could never use it. iOS needs spirv-cross and
    shaderc cross-built for iOS, which this script does not do yet.
  - libplacebo is built as shared framework to keep LGPL dynamic-link compliance.
  - Host needs meson, ninja and Homebrew shaderc + spirv-cross (static archives).
USAGE
}

CLEAN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            CLEAN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            ;;
    esac
done

check_tooling() {
    local missing=()
    for cmd in meson ninja xcodebuild git grep pkg-config; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
    fi
}

prepare_sources() {
    if [[ ! -d "$LIBPLACEBO_SRC_DIR/.git" ]]; then
        log "Cloning libplacebo from $LIBPLACEBO_REPO"
        git clone --filter=blob:none "$LIBPLACEBO_REPO" "$LIBPLACEBO_SRC_DIR"
    fi

    if ! git -C "$LIBPLACEBO_SRC_DIR" cat-file -e "${LIBPLACEBO_COMMIT}^{commit}" 2>/dev/null; then
        git -C "$LIBPLACEBO_SRC_DIR" fetch origin
    fi
    git -C "$LIBPLACEBO_SRC_DIR" checkout --detach "$LIBPLACEBO_COMMIT"
    git -C "$LIBPLACEBO_SRC_DIR" submodule update --init --depth 1 -- \
        3rdparty/jinja 3rdparty/markupsafe 3rdparty/fast_float 3rdparty/metal-cpp
}

prepare_meson_cross_file() {
    local sysroot="$1"
    local cross_file="$2"
    local flags="'-arch', 'arm64', '-isysroot', '$sysroot', '-mmacosx-version-min=$MACOS_MIN'"

    cat > "$cross_file" <<CROSS
[binaries]
c = 'clang'
cpp = 'clang++'
objc = 'clang'
objcpp = 'clang++'
ar = 'ar'
strip = 'strip'
pkgconfig = 'pkg-config'

[host_machine]
system = 'darwin'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'

[properties]
c_args = [$flags]
cpp_args = [$flags]
c_link_args = [$flags]
cpp_link_args = [$flags]
CROSS
}

prepare_shaderc_static_pkgconfig() {
    local shaderc_prefix
    shaderc_prefix="$(brew --prefix shaderc 2>/dev/null || true)"
    if [[ -z "$shaderc_prefix" || ! -f "$shaderc_prefix/lib/libshaderc_combined.a" ]]; then
        return 1
    fi

    local pc_dir="$BUILD_DIR/pkgconfig_shaderc_static"
    mkdir -p "$pc_dir"
    cat > "$pc_dir/shaderc.pc" <<SHADERC_PC
prefix=$shaderc_prefix
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: shaderc
Description: Static shaderc (combined archive) for libplacebo
Version: 2025.3
Libs: \${libdir}/libshaderc_combined.a -lc++
Cflags: -I\${includedir}
SHADERC_PC

    echo "$pc_dir"
}

build_libplacebo() {
    local build_dir="$BUILD_DIR/libplacebo_macos_arm64"
    local install_dir="$BUILD_DIR/libplacebo_install_macos_arm64"
    local cross_file="$BUILD_DIR/cross_macos_arm64.ini"

    prepare_meson_cross_file "$(xcrun --sdk macosx --show-sdk-path)" "$cross_file"
    rm -rf "$build_dir" "$install_dir"

    # The Metal backend compiles GLSL -> SPIR-V (shaderc) -> MSL (spirv-cross),
    # so a SPIR-V compiler is mandatory now, not best-effort.
    local shaderc_pc_dir
    shaderc_pc_dir="$(prepare_shaderc_static_pkgconfig)" || error "Homebrew shaderc (libshaderc_combined.a) not found"

    log "Configuring libplacebo for macOS/arm64"
    PKG_CONFIG_PATH="$shaderc_pc_dir:${PKG_CONFIG_PATH:-}" \
    meson setup "$build_dir" "$LIBPLACEBO_SRC_DIR" \
        --buildtype release \
        --default-library shared \
        --cross-file "$cross_file" \
        -Dmetal=enabled \
        -Dvulkan=disabled \
        -Dopengl=disabled \
        -Dd3d11=disabled \
        -Dglslang=disabled \
        -Dshaderc=enabled \
        -Dxxhash=disabled \
        -Dlcms=disabled \
        -Ddemos=false \
        -Dtests=false \
        -Dprefix="$install_dir" >&2

    ninja -C "$build_dir" >&2
    meson install -C "$build_dir" >&2

    # Meson installs a dylib, wrap it in a .framework for xcodebuild -create-xcframework
    wrap_dylib_as_framework "$install_dir"

    echo "$install_dir/lib/libplacebo.framework"
}

wrap_dylib_as_framework() {
    local install_dir="$1"
    local headers_src="$install_dir/include/libplacebo"
    local fw_dir="$install_dir/lib/libplacebo.framework"
    local dylib version

    # soversion is the API version (e.g. libplacebo.392.dylib); take the real file, not a symlink.
    dylib="$(find "$install_dir/lib" -maxdepth 1 -type f -name 'libplacebo.*.dylib' | head -n 1)"
    [[ -n "$dylib" ]] || error "dylib not found under $install_dir/lib"
    version="$(pkg-config --modversion "$install_dir/lib/pkgconfig/libplacebo.pc")"

    rm -rf "$fw_dir"
    mkdir -p "$fw_dir/Versions/A/Headers" "$fw_dir/Versions/A/Resources"
    cp "$dylib" "$fw_dir/Versions/A/libplacebo"
    cp -R "$headers_src"/* "$fw_dir/Versions/A/Headers/"

    # Set framework install name
    install_name_tool -id "@rpath/libplacebo.framework/libplacebo" "$fw_dir/Versions/A/libplacebo"

    cat > "$fw_dir/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>libplacebo</string>
    <key>CFBundleIdentifier</key>
    <string>org.videolan.libplacebo</string>
    <key>CFBundleName</key>
    <string>libplacebo</string>
    <key>CFBundleVersion</key>
    <string>${version}</string>
    <key>CFBundleShortVersionString</key>
    <string>${version}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MACOS_MIN}</string>
</dict>
</plist>
PLIST

    # Create symlinks
    ln -sf A "$fw_dir/Versions/Current"
    ln -sf Versions/Current/libplacebo "$fw_dir/libplacebo"
    ln -sf Versions/Current/Headers "$fw_dir/Headers"
    ln -sf Versions/Current/Resources "$fw_dir/Resources"

    # Ad-hoc sign the framework bundle so Xcode's CodeSign on Copy can re-sign it
    codesign --force -s - "$fw_dir"
}

validate_outputs() {
    local bin="$OUT_LIBPLACEBO_XCF/macos-arm64/libplacebo.framework/libplacebo"
    [[ -f "$bin" ]] || error "No libplacebo binary found in xcframework"

    log "Verifying libplacebo linkage and exports"
    local deps
    deps="$(otool -L "$bin")"
    if grep -q "/opt/homebrew/" <<<"$deps"; then
        error "libplacebo has host-local Homebrew dylib dependency:\n$deps"
    fi
    if grep -qi "vulkan\|MoltenVK" <<<"$deps"; then
        error "libplacebo still links a Vulkan loader / MoltenVK:\n$deps"
    fi
    local exports
    exports="$(nm -gU "$bin")"
    for sym in _pl_metal_create _pl_metal_create_swapchain _pl_metal_destroy; do
        grep -q " T $sym\$" <<<"$exports" || error "libplacebo does not export $sym (Metal backend missing?)"
    done

    log "Artifact ready: $OUT_LIBPLACEBO_XCF"
}

main() {
    check_tooling

    if [[ $CLEAN -eq 1 ]]; then
        log "Cleaning previous libplacebo artifacts"
        rm -rf \
            "$BUILD_DIR/libplacebo_"* \
            "$BUILD_DIR/libplacebo_install_"* \
            "$BUILD_DIR/cross_"* \
            "$OUT_LIBPLACEBO_XCF"
    fi

    prepare_sources

    local framework
    framework="$(build_libplacebo)"

    rm -rf "$OUT_LIBPLACEBO_XCF"
    log "Creating libplacebo.xcframework"
    xcodebuild -create-xcframework -framework "$framework" -output "$OUT_LIBPLACEBO_XCF"

    validate_outputs
}

main "$@"
