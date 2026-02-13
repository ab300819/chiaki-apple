#!/bin/bash
set -euo pipefail

# @requirement F-042 - libplacebo 渲染后端集成
# @satisfies AC-170 - MoltenVK 路径平台编译
# @satisfies AC-171 - 预编译 xcframework 集成
# @satisfies AC-172 - 动态 framework 链接

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/build_utils.sh"

LIBPLACEBO_VERSION="7.349.0"
MOLTENVK_VERSION="1.4.1"

LIBPLACEBO_URL="https://code.videolan.org/videolan/libplacebo/-/archive/v${LIBPLACEBO_VERSION}/libplacebo-v${LIBPLACEBO_VERSION}.tar.gz"
MOLTENVK_URL="https://github.com/KhronosGroup/MoltenVK/releases/download/v${MOLTENVK_VERSION}/MoltenVK-all.tar"

LIBPLACEBO_SRC_DIR="$BUILD_DIR/libplacebo-${LIBPLACEBO_VERSION}"
MOLTENVK_SRC_DIR="$BUILD_DIR/MoltenVK"

OUT_LIBPLACEBO_XCF="$FRAMEWORKS_DIR/libplacebo.xcframework"
OUT_MOLTENVK_XCF="$FRAMEWORKS_DIR/MoltenVK.xcframework"

usage() {
    cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --platform <all|macos|ios>   Build target platforms (default: all)
  --clean                      Remove prior libplacebo build artifacts first
  --skip-download              Reuse existing source archives/directories
  -h, --help                   Show this help

Notes:
  - libplacebo is built as shared framework to keep LGPL dynamic-link compliance.
  - This script assumes libplacebo Meson subprojects resolve shader deps.
  - Meson/Ninja/Vulkan toolchain setup is required on host.
USAGE
}

PLATFORM="all"
CLEAN=0
SKIP_DOWNLOAD=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --skip-download)
            SKIP_DOWNLOAD=1
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

if [[ "$PLATFORM" != "all" && "$PLATFORM" != "macos" && "$PLATFORM" != "ios" ]]; then
    error "Invalid --platform value: $PLATFORM"
fi

check_tooling() {
    local missing=()
    for cmd in meson ninja xcodebuild curl tar lipo grep; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
    fi
}

prepare_sources() {
    if [[ $SKIP_DOWNLOAD -eq 1 ]]; then
        log "Skipping downloads; reusing existing sources"
        return
    fi

    download_and_extract "$LIBPLACEBO_URL" "libplacebo-${LIBPLACEBO_VERSION}"

    if [[ ! -d "$MOLTENVK_SRC_DIR" ]]; then
        log "Downloading MoltenVK ${MOLTENVK_VERSION}..."
        local moltenvk_tar="$BUILD_DIR/MoltenVK-all-${MOLTENVK_VERSION}.tar"
        curl -L -o "$moltenvk_tar" "$MOLTENVK_URL"
        mkdir -p "$MOLTENVK_SRC_DIR"
        tar -xf "$moltenvk_tar" -C "$MOLTENVK_SRC_DIR" --strip-components=1
    fi
}

prepare_meson_cross_file() {
    local arch="$1"
    local sysroot="$2"
    local deployment_flag="$3"
    local cross_file="$4"

    cat > "$cross_file" <<CROSS
[binaries]
c = 'clang'
cpp = 'clang++'
ar = 'ar'
strip = 'strip'
pkgconfig = 'pkg-config'

[host_machine]
system = 'darwin'
cpu_family = '$([[ "$arch" == "x86_64" ]] && echo x86_64 || echo aarch64)'
cpu = '$arch'
endian = 'little'

[properties]
# Explicit flags keep cross-file self-describing for CI/review.
c_args = ['-arch', '$arch', '-isysroot', '$sysroot', '$deployment_flag']
cpp_args = ['-arch', '$arch', '-isysroot', '$sysroot', '$deployment_flag']
c_link_args = ['-arch', '$arch', '-isysroot', '$sysroot', '$deployment_flag']
cpp_link_args = ['-arch', '$arch', '-isysroot', '$sysroot', '$deployment_flag']
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

build_libplacebo_slice() {
    local platform="$1"
    local arch="$2"
    local sdk
    local sysroot
    local deployment_flag
    local build_dir="$BUILD_DIR/libplacebo_${platform}_${arch}"
    local install_dir="$BUILD_DIR/libplacebo_install_${platform}_${arch}"
    local cross_file="$BUILD_DIR/cross_${platform}_${arch}.ini"

    case "$platform" in
        macos)
            sdk="macosx"
            deployment_flag="-mmacosx-version-min=14.0"
            ;;
        ios)
            sdk="iphoneos"
            deployment_flag="-miphoneos-version-min=17.0"
            ;;
        ios-simulator)
            sdk="iphonesimulator"
            deployment_flag="-mios-simulator-version-min=17.0"
            ;;
        *)
            error "Unknown platform for libplacebo slice: $platform"
            ;;
    esac

    sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"

    prepare_meson_cross_file "$arch" "$sysroot" "$deployment_flag" "$cross_file"

    rm -rf "$build_dir" "$install_dir"

    local registry="/opt/homebrew/share/vulkan/registry/vk.xml"
    if [[ ! -f "$registry" ]]; then
        registry=$(find /opt/homebrew -name vk.xml | head -n 1)
    fi

    # Enable shaderc (SPIR-V compiler) for macOS arm64 where Homebrew provides it.
    # Without a SPIR-V compiler, pl_vulkan_create fails at runtime.
    # Other slices (x86_64, iOS) disable shaderc and fall back to Metal Native.
    local shaderc_opt="disabled"
    local pkg_config_env=""
    if [[ "$platform" == "macos" && "$arch" == "arm64" ]]; then
        local shaderc_pc_dir
        shaderc_pc_dir="$(prepare_shaderc_static_pkgconfig)" || true
        if [[ -n "$shaderc_pc_dir" ]]; then
            shaderc_opt="enabled"
            pkg_config_env="PKG_CONFIG_PATH=$shaderc_pc_dir:${PKG_CONFIG_PATH:-}"
            log "Enabling shaderc (static) for $platform/$arch"
        else
            log "WARNING: shaderc not found; libplacebo will lack SPIR-V compiler"
        fi
    fi

    log "Configuring libplacebo for $platform/$arch"
    env $pkg_config_env \
    meson setup "$build_dir" "$LIBPLACEBO_SRC_DIR" \
        --buildtype release \
        --default-library shared \
        --cross-file "$cross_file" \
        -Dvulkan=enabled \
        -Dvulkan-registry="$registry" \
        -Dopengl=disabled \
        -Dglslang=disabled \
        -Ddemos=false \
        -Dtests=false \
        -Dlcms=disabled \
        -Dshaderc="$shaderc_opt" \
        -Dprefix="$install_dir" >&2

    ninja -C "$build_dir" >&2
    meson install -C "$build_dir" >&2

    # Meson installs a dylib, wrap it in a .framework for xcodebuild -create-xcframework
    wrap_dylib_as_framework "$install_dir"

    echo "$install_dir"
}

wrap_dylib_as_framework() {
    local install_dir="$1"
    local dylib="$install_dir/lib/libplacebo.349.dylib"
    local headers_src="$install_dir/include/libplacebo"
    local fw_dir="$install_dir/lib/libplacebo.framework"

    [[ -f "$dylib" ]] || error "dylib not found: $dylib"

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
    <string>${LIBPLACEBO_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${LIBPLACEBO_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
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

patch_libplacebo_framework_deps() {
    local framework_root="$1"
    local bin="$framework_root/libplacebo"

    if [[ ! -f "$bin" && -f "$framework_root/Versions/A/libplacebo" ]]; then
        bin="$framework_root/Versions/A/libplacebo"
    fi
    [[ -f "$bin" ]] || error "Cannot find libplacebo binary under $framework_root"

    local deps
    deps="$(otool -L "$bin" | tr -d '\r')"

    if grep -q "/opt/homebrew/opt/vulkan-loader/lib/libvulkan.1.dylib" <<<"$deps"; then
        install_name_tool -change \
            "/opt/homebrew/opt/vulkan-loader/lib/libvulkan.1.dylib" \
            "@rpath/MoltenVK.framework/MoltenVK" \
            "$bin"
    fi

    if grep -q "/opt/homebrew/Cellar/vulkan-loader/.*/lib/libvulkan.1.dylib" <<<"$deps"; then
        local cellar_vulkan
        cellar_vulkan="$(grep -Eo "/opt/homebrew/Cellar/vulkan-loader/[^ ]+/lib/libvulkan\\.1\\.dylib" <<<"$deps" | head -n 1)"
        install_name_tool -change \
            "$cellar_vulkan" \
            "@rpath/MoltenVK.framework/MoltenVK" \
            "$bin"
    fi

    if grep -q "libshaderc_shared.1.dylib" <<<"$deps"; then
        error "Unexpected shaderc dynamic dependency in libplacebo (should be statically linked): $bin"
    fi
}

create_universal_macos_framework() {
    local arm64_install="$1"
    local x86_install="$2"
    local out_root="$BUILD_DIR/libplacebo_install_macos_universal"
    local out_framework="$out_root/lib/libplacebo.framework"
    local arm64_framework="$arm64_install/lib/libplacebo.framework"
    local x86_framework="$x86_install/lib/libplacebo.framework"

    if [[ ! -d "$arm64_framework" || ! -d "$x86_framework" ]]; then
        error "Cannot create universal macOS framework; arm64/x86_64 slices are missing"
    fi

    rm -rf "$out_root"
    mkdir -p "$out_root/lib"
    cp -R "$arm64_framework" "$out_framework"

    lipo -create \
        "$arm64_framework/libplacebo" \
        "$x86_framework/libplacebo" \
        -output "$out_framework/libplacebo"

    patch_libplacebo_framework_deps "$out_framework"

    echo "$out_framework"
}

create_libplacebo_xcframework() {
    local macos_framework="${1:-}"
    local ios_framework="${2:-}"
    local ios_sim_framework="${3:-}"
    local args=()

    [[ -n "$macos_framework" ]] && args+=( -framework "$macos_framework" )
    [[ -n "$ios_framework" ]] && args+=( -framework "$ios_framework" )
    [[ -n "$ios_sim_framework" ]] && args+=( -framework "$ios_sim_framework" )

    if [[ ${#args[@]} -eq 0 ]]; then
        error "No libplacebo framework slices to package"
    fi

    rm -rf "$OUT_LIBPLACEBO_XCF"
    log "Creating libplacebo.xcframework"
    xcodebuild -create-xcframework "${args[@]}" -output "$OUT_LIBPLACEBO_XCF"
}

create_moltenvk_xcframework() {
    local platform="$1"
    # MoltenVK tar layout may vary; check both known paths
    local mvk_base=""
    if [[ -d "$MOLTENVK_SRC_DIR/Package/Release/MoltenVK/dynamic/MoltenVK.xcframework" ]]; then
        mvk_base="$MOLTENVK_SRC_DIR/Package/Release/MoltenVK/dynamic/MoltenVK.xcframework"
    elif [[ -d "$MOLTENVK_SRC_DIR/MoltenVK/dynamic/MoltenVK.xcframework" ]]; then
        mvk_base="$MOLTENVK_SRC_DIR/MoltenVK/dynamic/MoltenVK.xcframework"
    else
        error "Cannot locate MoltenVK.xcframework in $MOLTENVK_SRC_DIR"
    fi
    local macos_framework="$mvk_base/macos-arm64_x86_64/MoltenVK.framework"
    local ios_framework="$mvk_base/ios-arm64/MoltenVK.framework"
    local args=()

    case "$platform" in
        all)
            [[ -d "$macos_framework" ]] || error "Missing MoltenVK macOS dynamic framework"
            [[ -d "$ios_framework" ]] || error "Missing MoltenVK iOS dynamic framework"
            args+=( -framework "$macos_framework" -framework "$ios_framework" )
            ;;
        macos)
            [[ -d "$macos_framework" ]] || error "Missing MoltenVK macOS dynamic framework"
            args+=( -framework "$macos_framework" )
            ;;
        ios)
            [[ -d "$ios_framework" ]] || error "Missing MoltenVK iOS dynamic framework"
            args+=( -framework "$ios_framework" )
            ;;
        *)
            error "Unknown platform for MoltenVK packaging: $platform"
            ;;
    esac

    rm -rf "$OUT_MOLTENVK_XCF"
    log "Creating MoltenVK.xcframework"
    xcodebuild -create-xcframework "${args[@]}" -output "$OUT_MOLTENVK_XCF"
}

vendor_vulkan_headers() {
    local vulkan_src="$MOLTENVK_SRC_DIR/MoltenVK/include/vulkan"
    local vk_video_src="$MOLTENVK_SRC_DIR/MoltenVK/include/vk_video"
    local vulkan_dst="$FRAMEWORKS_DIR/VulkanHeaders/include/vulkan"
    local vk_video_dst="$FRAMEWORKS_DIR/VulkanHeaders/include/vk_video"

    if [[ ! -d "$vulkan_src" ]]; then
        error "Vulkan headers not found at $vulkan_src"
    fi

    rm -rf "$FRAMEWORKS_DIR/VulkanHeaders"
    mkdir -p "$vulkan_dst" "$vk_video_dst"

    # Copy C headers needed by libplacebo/vulkan.h
    local headers=(vulkan.h vulkan_core.h vk_platform.h vulkan_metal.h vulkan_macos.h vulkan_ios.h vulkan_beta.h vk_icd.h vk_layer.h)
    for h in "${headers[@]}"; do
        if [[ -f "$vulkan_src/$h" ]]; then
            cp "$vulkan_src/$h" "$vulkan_dst/"
        fi
    done

    # Copy vk_video headers (required by vulkan_core.h)
    if [[ -d "$vk_video_src" ]]; then
        cp "$vk_video_src"/*.h "$vk_video_dst/"
    fi

    log "Vendored Vulkan headers to $FRAMEWORKS_DIR/VulkanHeaders/include"
}

validate_outputs() {
    [[ -d "$OUT_LIBPLACEBO_XCF" ]] || error "Missing output: $OUT_LIBPLACEBO_XCF"
    [[ -d "$OUT_MOLTENVK_XCF" ]] || error "Missing output: $OUT_MOLTENVK_XCF"

    local libplacebo_bin=""
    if [[ -f "$OUT_LIBPLACEBO_XCF/macos-arm64_x86_64/libplacebo.framework/libplacebo" ]]; then
        libplacebo_bin="$OUT_LIBPLACEBO_XCF/macos-arm64_x86_64/libplacebo.framework/libplacebo"
    elif [[ -f "$OUT_LIBPLACEBO_XCF/macos-arm64/libplacebo.framework/libplacebo" ]]; then
        libplacebo_bin="$OUT_LIBPLACEBO_XCF/macos-arm64/libplacebo.framework/libplacebo"
    elif [[ -f "$OUT_LIBPLACEBO_XCF/ios-arm64/libplacebo.framework/libplacebo" ]]; then
        libplacebo_bin="$OUT_LIBPLACEBO_XCF/ios-arm64/libplacebo.framework/libplacebo"
    fi

    if [[ -n "$libplacebo_bin" ]]; then
        log "Verifying libplacebo dynamic linkage"
        local deps
        deps="$(otool -L "$libplacebo_bin")"
        grep -q "libplacebo" <<<"$deps" || error "libplacebo binary linkage check failed"
        grep -q "@rpath/MoltenVK.framework/MoltenVK" <<<"$deps" || error "libplacebo does not link to embedded MoltenVK framework"
        if grep -q "/opt/homebrew/" <<<"$deps"; then
            error "libplacebo has host-local Homebrew dylib dependency:\n$deps"
        fi
        if grep -q "libshaderc_shared.1.dylib" <<<"$deps"; then
            error "libplacebo unexpectedly links against shaderc shared runtime (should be static):\n$deps"
        fi
    else
        error "No libplacebo binary found in xcframework"
    fi

    log "Artifacts ready:"
    log "  - $OUT_LIBPLACEBO_XCF"
    log "  - $OUT_MOLTENVK_XCF"
}

main() {
    check_tooling

    if [[ $CLEAN -eq 1 ]]; then
        log "Cleaning previous libplacebo artifacts"
        rm -rf \
            "$BUILD_DIR/libplacebo_"* \
            "$BUILD_DIR/libplacebo_install_"* \
            "$BUILD_DIR/cross_"* \
            "$OUT_LIBPLACEBO_XCF" \
            "$OUT_MOLTENVK_XCF"
    fi

    prepare_sources

    local macos_framework=""
    local ios_framework=""
    local ios_sim_framework=""

    if [[ "$PLATFORM" == "all" || "$PLATFORM" == "macos" ]]; then
        local macos_install_arm64
        macos_install_arm64="$(build_libplacebo_slice macos arm64)"

        # x86_64 build requires a Vulkan loader with x86_64 support.
        # Homebrew's vulkan-loader is arm64-only on Apple Silicon hosts,
        # so x86_64 cross-compilation is best-effort.
        local macos_install_x86_64=""
        if macos_install_x86_64="$(build_libplacebo_slice macos x86_64 2>&1)"; then
            macos_framework="$(create_universal_macos_framework "$macos_install_arm64" "$macos_install_x86_64")"
        else
            log "WARNING: x86_64 build failed (expected on arm64-only Vulkan host); creating arm64-only framework"
            local arm64_framework="$macos_install_arm64/lib/libplacebo.framework"
            patch_libplacebo_framework_deps "$arm64_framework"
            macos_framework="$arm64_framework"
        fi
    fi

    if [[ "$PLATFORM" == "all" || "$PLATFORM" == "ios" ]]; then
        local ios_install
        local ios_sim_install
        ios_install="$(build_libplacebo_slice ios arm64)"
        ios_sim_install="$(build_libplacebo_slice ios-simulator arm64)"
        ios_framework="$ios_install/lib/libplacebo.framework"
        ios_sim_framework="$ios_sim_install/lib/libplacebo.framework"
        patch_libplacebo_framework_deps "$ios_framework"
        patch_libplacebo_framework_deps "$ios_sim_framework"
    fi

    create_libplacebo_xcframework "$macos_framework" "$ios_framework" "$ios_sim_framework"
    create_moltenvk_xcframework "$PLATFORM"
    vendor_vulkan_headers
    validate_outputs
}

main "$@"
