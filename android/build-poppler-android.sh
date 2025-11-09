#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# User configurable (can also be set via env vars before invoking the script)
NDK_ROOT="${NDK_ROOT:-${ANDROID_NDK_ROOT:-${ANDROID_SDK_ROOT:-}/ndk/25.2.9519653}}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-23}"
QT_ANDROID_PREFIX="${QT_ANDROID_PREFIX:-${PROJECT_ROOT}/../qt6-android-arm64-build/qtbase}"
QT_HOST_PATH="${QT_HOST_PATH:-${PROJECT_ROOT}/../qt6-install}"
THIRD_PARTY_DIR="${THIRD_PARTY_DIR:-${PROJECT_ROOT}/third_party}"
BUILD_ROOT="${BUILD_ROOT:-${PROJECT_ROOT}/android/poppler-build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-${PROJECT_ROOT}/android/poppler-sysroot}"

# Source directories for dependencies (override if you use different names)
LIBJPEG_TURBO_SRC="${LIBJPEG_TURBO_SRC:-${THIRD_PARTY_DIR}/libjpeg-turbo}"
FREETYPE_SRC="${FREETYPE_SRC:-${THIRD_PARTY_DIR}/freetype}"
OPENJPEG_SRC="${OPENJPEG_SRC:-${THIRD_PARTY_DIR}/openjpeg}"
POPLER_SRC="${POPLER_SRC:-${PROJECT_ROOT}/../poppler}"

# -----------------------------------------------------------------------------
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
fail() { echo -e "\033[1;31m[ERR ]\033[0m $*"; exit 1; }

check_dir() {
    if [[ ! -d "$1" ]]; then
        fail "Missing directory: $1"
    fi
}

ensure_prerequisites() {
    check_dir "$NDK_ROOT"
    check_dir "$QT_ANDROID_PREFIX"
    check_dir "$POPLER_SRC"

    mkdir -p "$BUILD_ROOT" "$INSTALL_PREFIX" "$THIRD_PARTY_DIR"

    if ! command -v ninja >/dev/null 2>&1; then
        fail "ninja not found in PATH. Install Ninja and retry."
    fi

    if ! command -v cmake >/dev/null 2>&1; then
        fail "cmake not found in PATH. Install CMake 3.20+ and retry."
    fi

    export PKG_CONFIG_LIBDIR="${INSTALL_PREFIX}/lib/pkgconfig"
    export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
    export PKG_CONFIG_SYSROOT_DIR="$INSTALL_PREFIX"
}

toolchain_args=(
    "-DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake"
    "-DANDROID_ABI=${ANDROID_ABI}"
    "-DANDROID_PLATFORM=${ANDROID_PLATFORM}"
    "-DANDROID_STL=c++_shared"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    "-G" "Ninja"
)

cmake_configure() {
    local src="$1"
    local build="$2"
    shift 2
    cmake "$src" -B "$build" "${toolchain_args[@]}" "$@"
}

build_and_install() {
    local build="$1"
    cmake --build "$build"
    cmake --install "$build"
}

build_libjpeg_turbo() {
    if [[ ! -d "$LIBJPEG_TURBO_SRC" ]]; then
        warn "Skipping libjpeg-turbo (source directory missing): $LIBJPEG_TURBO_SRC"
        return
    fi
    info "Building libjpeg-turbo"
    local build_dir="$BUILD_ROOT/libjpeg-turbo"
    cmake_configure "$LIBJPEG_TURBO_SRC" "$build_dir" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DENABLE_SHARED=OFF \
        -DENABLE_STATIC=ON \
        -DWITH_TURBOJPEG=OFF \
        -DWITH_JPEG8=ON
    build_and_install "$build_dir"
}

build_freetype() {
    if [[ ! -d "$FREETYPE_SRC" ]]; then
        warn "Skipping FreeType (source directory missing): $FREETYPE_SRC"
        return
    fi
    info "Building FreeType"
    local build_dir="$BUILD_ROOT/freetype"
    cmake_configure "$FREETYPE_SRC" "$build_dir" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DFT_DISABLE_BZIP2=ON \
        -DFT_DISABLE_HARFBUZZ=ON \
        -DFT_DISABLE_BROTLI=ON
    build_and_install "$build_dir"
}

build_openjpeg() {
    if [[ ! -d "$OPENJPEG_SRC" ]]; then
        warn "Skipping OpenJPEG (source directory missing): $OPENJPEG_SRC"
        return
    fi
    info "Building OpenJPEG"
    local build_dir="$BUILD_ROOT/openjpeg"
    cmake_configure "$OPENJPEG_SRC" "$build_dir" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_CODEC=OFF \
        -DOPENJPEG_INSTALL_INCLUDE_DIR=include
    build_and_install "$build_dir"
}

build_poppler() {
    info "Building Poppler (${POPLER_SRC})"
    local build_dir="$BUILD_ROOT/poppler"

    cmake_configure "$POPLER_SRC" "$build_dir" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX};${QT_ANDROID_PREFIX}" \
        -DCMAKE_FIND_ROOT_PATH="${INSTALL_PREFIX};${QT_ANDROID_PREFIX}" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DBUILD_SHARED_LIBS=ON \
        -DENABLE_UTILS=OFF \
        -DENABLE_CPP=ON \
        -DENABLE_GLIB=OFF \
        -DENABLE_QT5=OFF \
        -DENABLE_QT6=ON \
        -DENABLE_LIBCURL=OFF \
        -DENABLE_LIBTIFF=OFF \
        -DENABLE_JPEG=ON \
        -DENABLE_OPENJPEG=ON \
        -DENABLE_UNSTABLE_API_ABI_HEADERS=ON \
        -DQt6_DIR="${QT_ANDROID_PREFIX}/lib/cmake/Qt6" \
        -DQt6Core_DIR="${QT_ANDROID_PREFIX}/lib/cmake/Qt6Core" \
        -DQt6Gui_DIR="${QT_ANDROID_PREFIX}/lib/cmake/Qt6Gui" \
        -DQt6Widgets_DIR="${QT_ANDROID_PREFIX}/lib/cmake/Qt6Widgets" \
        -DQt6Network_DIR="${QT_ANDROID_PREFIX}/lib/cmake/Qt6Network" \
        -DQt6Xml_DIR="${QT_ANDROID_PREFIX}/lib/cmake/Qt6Xml"

    build_and_install "$build_dir"

    info "Poppler installed to ${INSTALL_PREFIX}"
    info "Remember to copy ${INSTALL_PREFIX}/lib/*.so into your Android package"
}

main() {
    ensure_prerequisites
    build_libjpeg_turbo
    build_freetype
    build_openjpeg
    build_poppler

    info "Poppler build complete"
    info "Set SPEEDYNOTE_POPPLER_SYSROOT=${INSTALL_PREFIX} when configuring the Android build."
}

main "$@"
