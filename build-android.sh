#!/usr/bin/env bash
set -euo pipefail

# Android build helper for SpeedyNote (简化版)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
BUILD_DIR="${PROJECT_ROOT}/build-android"

if [[ "${1:-}" == "--clean" ]]; then
    rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}"

QT_ANDROID_CMAKE_BIN="${QT_ANDROID_CMAKE:-/opt/qt6-android-arm64/bin/qt-cmake}"
QT_HOST_PATH_VALUE="${QT_HOST_PATH:-/opt/qt6-install}"
QT_ANDROID_PREFIX="${QT_ANDROID_PREFIX:-/opt/qt6-android-arm64}"
ANDROID_PLATFORM_VALUE="${ANDROID_PLATFORM:-android-23}"
ANDROID_ABI_VALUE="${ANDROID_ABI:-arm64-v8a}"
ANDROID_STL_VALUE="${ANDROID_STL:-c++_shared}"

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

"${QT_ANDROID_CMAKE_BIN}" \
    -S "${PROJECT_ROOT}" \
    -B "${BUILD_DIR}" \
    -DQT_HOST_PATH="${QT_HOST_PATH_VALUE}" \
    -DCMAKE_PREFIX_PATH="${QT_ANDROID_PREFIX}" \
    -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
    -DANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}" \
    -DANDROID_NDK_ROOT="${ANDROID_NDK_ROOT}" \
    -DANDROID_PLATFORM="${ANDROID_PLATFORM_VALUE}" \
    -DANDROID_ABI="${ANDROID_ABI_VALUE}" \
    -DANDROID_STL="${ANDROID_STL_VALUE}" \
    ${EXTRA_CMAKE_ARGS:-}

cmake --build "${BUILD_DIR}" --parallel
cmake --build "${BUILD_DIR}" --target apk --parallel

APK_DIR="${BUILD_DIR}/android-build"
if [[ -d "${APK_DIR}" ]]; then
    echo "APK 目录: ${APK_DIR}"
    find "${APK_DIR}" -maxdepth 1 -type f -name "*.apk" -print
else
    echo "未发现 APK 输出目录 ${APK_DIR}" >&2
fi
