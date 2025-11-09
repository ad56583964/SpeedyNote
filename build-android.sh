#!/usr/bin/env bash
set -euo pipefail

# SpeedyNote Android build helper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
BUILD_DIR="${PROJECT_ROOT}/build-android"

if [[ "${1:-}" == "--clean" ]]; then
    rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}"

QT_ANDROID_CMAKE_BIN="${QT_ANDROID_CMAKE:-/opt/qt6-android-arm64/bin/qt-cmake}"
QT_ANDROID_PREFIX="${QT_ANDROID_PREFIX:-/opt/qt6-android-arm64}"
QT_HOST_PATH_VALUE="${QT_HOST_PATH:-/opt/qt6-install}"
APP_NAME_VALUE="${APP_NAME:-NoteApp}"
ANDROID_PLATFORM_VALUE="${ANDROID_PLATFORM:-android-23}"
ANDROID_ABI_VALUE="${ANDROID_ABI:-arm64-v8a}"
ANDROID_STL_VALUE="${ANDROID_STL:-c++_shared}"
POPPLER_SYSROOT_VALUE="${SPEEDYNOTE_POPPLER_SYSROOT:-/opt/third-party/sysroot}"
PKG_CONFIG_LIBDIR_VALUE="${PKG_CONFIG_LIBDIR:-${POPPLER_SYSROOT_VALUE}/lib/pkgconfig:${POPPLER_SYSROOT_VALUE}/share/pkgconfig}"
CMAKE_BUILD_TYPE_VALUE="${CMAKE_BUILD_TYPE:-Debug}"

if [[ ! -x "${QT_ANDROID_CMAKE_BIN}" ]]; then
    echo "未找到 qt-cmake: ${QT_ANDROID_CMAKE_BIN}" >&2
    exit 1
fi
if [[ -z "${ANDROID_SDK_ROOT:-}" ]]; then
    echo "ANDROID_SDK_ROOT 未设置" >&2
    exit 1
fi
if [[ -z "${ANDROID_NDK_ROOT:-}" ]]; then
    echo "ANDROID_NDK_ROOT 未设置" >&2
    exit 1
fi

CMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake"
ANDROID_SYSROOT="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
DEFAULT_FIND_ROOT_PATH="${ANDROID_SYSROOT};${QT_ANDROID_PREFIX}"

if [[ -n "${CMAKE_FIND_ROOT_PATH:-}" ]]; then
    FIND_ROOT_PATH_VALUE="${CMAKE_FIND_ROOT_PATH};${POPPLER_SYSROOT_VALUE}"
else
    FIND_ROOT_PATH_VALUE="${DEFAULT_FIND_ROOT_PATH};${POPPLER_SYSROOT_VALUE}"
fi

export PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR_VALUE}"

"${QT_ANDROID_CMAKE_BIN}" \
    -S "${PROJECT_ROOT}" \
    -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE_VALUE}" \
    -DQT_HOST_PATH="${QT_HOST_PATH_VALUE}" \
    -DCMAKE_PREFIX_PATH="${QT_ANDROID_PREFIX};${QT_HOST_PATH_VALUE};${POPPLER_SYSROOT_VALUE}" \
    -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
    -DCMAKE_FIND_ROOT_PATH="${FIND_ROOT_PATH_VALUE}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
    -DANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}" \
    -DANDROID_NDK_ROOT="${ANDROID_NDK_ROOT}" \
    -DANDROID_PLATFORM="${ANDROID_PLATFORM_VALUE}" \
    -DANDROID_ABI="${ANDROID_ABI_VALUE}" \
    -DANDROID_STL="${ANDROID_STL_VALUE}" \
    -DSPEEDYNOTE_ENABLE_POPPLER=ON \
    -DSPEEDYNOTE_POPPLER_SYSROOT="${POPPLER_SYSROOT_VALUE}" \
    ${EXTRA_CMAKE_ARGS:-}

cmake --build "${BUILD_DIR}" --parallel
cmake --build "${BUILD_DIR}" --target "${APP_NAME_VALUE}_prepare_apk_dir" --parallel

ANDROIDDEPLOYQT_BIN="${QT_HOST_PATH_VALUE}/bin/androiddeployqt"
DEPLOYMENT_SETTINGS_FILE="${BUILD_DIR}/android-${APP_NAME_VALUE}-deployment-settings.json"
APK_OUTPUT_DIR="${BUILD_DIR}/android-build"
APK_OUTPUT_PATH="${APK_OUTPUT_DIR}/${APP_NAME_VALUE}.apk"

if [[ -x "${ANDROIDDEPLOYQT_BIN}" && -f "${DEPLOYMENT_SETTINGS_FILE}" ]]; then
    "${ANDROIDDEPLOYQT_BIN}" \
        --input "${DEPLOYMENT_SETTINGS_FILE}" \
        --output "${APK_OUTPUT_DIR}" \
        --apk "${APK_OUTPUT_PATH}" \
        --no-strip
elif [[ ! -x "${ANDROIDDEPLOYQT_BIN}" ]]; then
    echo "警告: 未找到 androiddeployqt (${ANDROIDDEPLOYQT_BIN})，无法追加 --no-strip" >&2
else
    echo "警告: 未找到部署配置文件 ${DEPLOYMENT_SETTINGS_FILE}" >&2
fi

APK_DIR="${BUILD_DIR}/android-build"
if [[ -d "${APK_DIR}" ]]; then
    echo "APK 目录: ${APK_DIR}"
    find "${APK_DIR}" -maxdepth 1 -type f -name "*.apk" -print
else
    echo "未发现 APK 输出目录 ${APK_DIR}" >&2
fi
