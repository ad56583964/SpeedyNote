# Poppler (24.02.0) for Android

本文档说明如何为 SpeedyNote 的 Android 版本交叉编译 Poppler 及其必备依赖。

## 1. 准备工作

- Android SDK + NDK（脚本默认使用 `ndk/25.2.9519653`）。
- 已构建好的 Qt for Android （默认路径 `../qt6-android-arm64-build/qtbase`）。
- 可执行的 `cmake` ≥ 3.20、`ninja`。
- Poppler 24.02.0 源码（例如位于 `~/Documents/qt6-space/poppler`）。
- 依赖源码放在 `SpeedyNote/third_party` 下：
  - `libjpeg-turbo`
  - `freetype`
  - `openjpeg`

> 若目录命名不同，可通过环境变量 `LIBJPEG_TURBO_SRC`、`FREETYPE_SRC`、`OPENJPEG_SRC` 指定。

## 2. 运行构建脚本

在 `SpeedyNote` 根目录下执行：

```bash
cd SpeedyNote
ANDROID_SDK_ROOT=/path/to/Android/Sdk \
QT_ANDROID_PREFIX=/path/to/qt6-android-arm64-build/qtbase \
./android/build-poppler-android.sh
```

脚本默认配置：

| 变量 | 默认值 |
| ---- | ------ |
| `ANDROID_ABI` | `arm64-v8a` |
| `ANDROID_PLATFORM` | `android-23` |
| `NDK_ROOT` | `$ANDROID_SDK_ROOT/ndk/25.2.9519653` |
| `QT_ANDROID_PREFIX` | `../qt6-android-arm64-build/qtbase` |
| `QT_HOST_PATH` | `../qt6-install`（仅用于查找主机工具） |
| `INSTALL_PREFIX` | `SpeedyNote/android/poppler-sysroot` |

脚本步骤：

1. 编译 `libjpeg-turbo`（若目录存在）。
2. 编译 `freetype`。
3. 编译 `openjpeg`。
4. 编译并安装 Poppler（启用 Qt6 绑定、禁用工具和非必要组件）。

最终产物安装在 `INSTALL_PREFIX`（默认 `android/poppler-sysroot`）。若缺少某个依赖源目录，脚本会跳过并给出警告。

> 建议在第一次执行前清理 `SpeedyNote/android/poppler-build` 和 `SpeedyNote/android/poppler-sysroot`，避免旧文件干扰。

## 3. 集成到 SpeedyNote Android 构建

1. 调用 `qt-cmake`（或等价配置）时添加：
   ```bash
   -DSPEEDYNOTE_ENABLE_POPPLER=ON \
   -DSPEEDYNOTE_POPPLER_SYSROOT=/absolute/path/to/SpeedyNote/android/poppler-sysroot
   ```

2. 若脚本输出在自定义位置，请同时把该目录加入 `CMAKE_PREFIX_PATH`（或通过环境变量 `CMAKE_PREFIX_PATH`）以便 CMake 找到 Poppler。

3. 构建完成后，确保 `androiddeployqt` 将以下文件包含在 APK/Bundle 中：
   - `libpoppler.so`
   - `libpoppler-qt6.so`
   - 依赖库（`libjpeg`, `libopenjp2`, `libfreetype` 等）。

   可在 `androiddeployqt` 的 `--extra-libs` 参数或 `ANDROID_EXTRA_LIBS` 变量中追加 `poppler-sysroot/lib/*.so`。

## 4. 常见问题

- **找不到 Poppler：** 确认 `SPEEDYNOTE_POPPLER_SYSROOT` 指向正确目录，并包含 `lib/cmake/Poppler/PopplerConfig.cmake`。
- **缺少依赖库**：若构建 Poppler 时提示缺失 `libjpeg` / `openjpeg`，检查第三方源码是否到位；脚本允许你自定义 `LIBJPEG_TURBO_SRC` 等变量。
- **包体积较大**：可考虑关闭不必要的模块（例如编译静态库后使用 `androiddeployqt --strip`) 或仅复制运行时必需的 `.so`。
- **ABI 支持**：脚本目前默认 `arm64-v8a`，如果需要其他 ABI，可设置 `ANDROID_ABI` 为 `armeabi-v7a` 等并重新执行。

完成上述步骤后，SpeedyNote 的 Android 构建即可重新启用 Poppler PDF 功能。若进一步需要自动化发布，可把此脚本集成到 CI 或自定义构建流水线中。 
