# Android 端改动细化（自 3016747 至 HEAD）

- **起始提交**：3016747bf3db02f43b5619e9637764ffc2bad286
- **当前 HEAD**：23709defbb25f63c7e1b15e54dbea3d7f843a7c1（短 SHA：23709de）
- **提交摘要**：
  - 23709de feat(android): add support for configurable app name and build type
  - 311fdf7 wip
  - 96b2a4f fix(MainWindow): adjust dial input handling and pdf document access
  - ad71e60 feat(android): enable Poppler PDF support with static linking
  - c73d402 build start
  - 19073b3 wip

---

## CMakeLists.txt（修改）
- **新增构建选项**：
  - `SPEEDYNOTE_ENABLE_POPPLER` / `SPEEDYNOTE_ENABLE_SDL` / `SPEEDYNOTE_ENABLE_AUDIO`（按平台设默认值，Android 默认关闭）。
  - `SPEEDYNOTE_POPPLER_SYSROOT`（Android 交叉构建时指定 Poppler 安装前缀）。
- **Android 专区（Poppler 静态链接）**：
  - 通过 `PkgConfig` 检索 `poppler-qt6`、`poppler`，启用 `PKG_CONFIG_USE_STATIC_LIBS ON`。
  - 聚合并去重：
    - `ANDROID_POPPLER_STATIC_LIBS`（含来自 pkg-config 的静/动库集合 + 手动追加：`lcms2 png jpeg openjp2 tiff z freetype`）。
    - `ANDROID_POPPLER_LIBRARY_DIRS`、`ANDROID_POPPLER_INCLUDE_DIRS`、`ANDROID_POPPLER_LINK_FLAGS`。
  - 在 `target_link_libraries(NoteApp ...)` 前增加：
    - `target_include_directories(NoteApp PRIVATE ${ANDROID_POPPLER_INCLUDE_DIRS})`
    - `target_link_directories(NoteApp PRIVATE ${ANDROID_POPPLER_LIBRARY_DIRS})`
    - `target_link_options(NoteApp PRIVATE ${ANDROID_POPPLER_LINK_FLAGS})`
    - `target_link_libraries(NoteApp PRIVATE ${ANDROID_POPPLER_STATIC_LIBS})`
- **跨平台收敛**：
  - Windows/Unix 的 Poppler/SDL 链接改为受开关控制。
  - 将 `add_executable` 替换为 `qt_add_executable`，并新增 `qt_finalize_executable`。
  - 为目标增加编译期宏：`SPEEDYNOTE_ENABLE_*` 三个选项对应的 0/1 宏。
- **检索路径**：
  - 当 `SPEEDYNOTE_POPPLER_SYSROOT` 有效时，追加到 `CMAKE_PREFIX_PATH`、`CMAKE_FIND_ROOT_PATH`。
- **快速定位**：
  - 关键词：`SPEEDYNOTE_ENABLE_POPPLER`、`pkg_check_modules(POPPLER_QT6`、`PKG_CONFIG_USE_STATIC_LIBS`、`qt_add_executable`、`qt_finalize_executable`。
  - 查看差异：`git diff 3016747..HEAD -- CMakeLists.txt`

---

## android/build-poppler-android.sh（新增）
- **作用**：在 Android NDK toolchain 下构建 Poppler 及依赖（libjpeg-turbo、freetype、openjpeg），产出到 `android/poppler-sysroot`。
- **关键参数**：
  - NDK/ABI/API：`ANDROID_ABI=arm64-v8a`，`ANDROID_PLATFORM=android-23`，`-DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake`。
  - Qt for Android 前缀：`QT_ANDROID_PREFIX/Qt6_*_DIR` 指向设备端 Qt。
  - Poppler 选项：`-DBUILD_SHARED_LIBS=ON -DENABLE_QT6=ON -DENABLE_UTILS=OFF -DENABLE_CPP=ON -DENABLE_GLIB=OFF -DENABLE_OPENJPEG=ON` 等。
- **快速定位**：
  - 关键词：`toolchain_args`、`cmake_configure`、`INSTALL_PREFIX`、`ENABLE_QT6`、`OPENJPEG`。
  - 查看全文：`git show HEAD:android/build-poppler-android.sh`

---

## build-android.sh（新增）
- **作用**：使用 `qt-cmake` 配置 + `androiddeployqt` 打包 APK。
- **关键点**：
  - 读取环境：`QT_ANDROID_CMAKE`、`QT_ANDROID_PREFIX`、`QT_HOST_PATH`、`ANDROID_{SDK,NDK}_ROOT`、`SPEEDYNOTE_POPPLER_SYSROOT`。
  - 设置 `PKG_CONFIG_LIBDIR` 指向 Poppler sysroot。
  - CMake 参数：`-DSPEEDYNOTE_ENABLE_POPPLER=ON -DSPEEDYNOTE_POPPLER_SYSROOT=...`。
  - 打包：`androiddeployqt --no-strip`，APK 输出到 `build-android/android-build/`。
- **快速定位**：
  - 关键词：`QT_ANDROID_CMAKE_BIN`、`ANDROIDDEPLOYQT_BIN`、`CMAKE_FIND_ROOT_PATH`、`EXTRA_CMAKE_ARGS`。
  - 查看全文：`git show HEAD:build-android.sh`

---

## docs/Android_Poppler_Build.md（新增）
- **内容**：记录 Android 下 Poppler 交叉构建步骤、默认参数、集成与常见问题。
- **快速定位**：`git show HEAD:docs/Android_Poppler_Build.md`

---

## .gitignore（修改）
- **新增忽略**：`build-android/`。
- **快速定位**：`git diff 3016747..HEAD -- .gitignore`

---

## source/ControlPanelDialog.cpp（修改）
- **新增宏守卫**：`SPEEDYNOTE_ENABLE_SDL`（默认若未定义则置 1，仍以 CMake 传入的定义为准）。
- **行为变更**：
  - `createControllerMappingTab()` / `openControllerMapping()` / `reconnectController()` / `updateControllerStatus()`：
    - 当 SDL 关闭时，替换为提示“当前平台不可用”的 UI/消息，不再调用 SDL 相关逻辑。
- **快速定位**：
  - 关键词：`#if SPEEDYNOTE_ENABLE_SDL`、`Controller mapping is not available`。
  - 查看差异：`git diff 3016747..HEAD -- source/ControlPanelDialog.cpp`

---

## source/ControllerMappingDialog.cpp（修改）
- **新增宏守卫**：`SPEEDYNOTE_ENABLE_SDL`。
- **行为变更**：
  - SDL 启用：保留原完整交互逻辑。
  - SDL 关闭：提供“不可用”对话框与空实现（`startButtonMapping`/`applyMappings` 等变为 no-op）。
- **快速定位**：
  - 关键词：`#if SPEEDYNOTE_ENABLE_SDL`、`Controller Mapping Unavailable`。
  - 查看差异：`git diff 3016747..HEAD -- source/ControllerMappingDialog.cpp`

---

## source/InkCanvas.h（修改）
- **新增宏守卫**：`SPEEDYNOTE_ENABLE_POPPLER`（未定义时默认 1）。
- **结构调整**：
  - 仅在开启 Poppler 时包含 `#include <poppler-qt6.h>`，并声明/持有相关类型：
    - `Poppler::Document`、`Poppler::Page`、`Poppler::TextBox` 等。
  - 接口受控：如 `getPdfDocument()`、承载 PDF 文本框/选择的成员、缓存成员在宏内声明。
- **快速定位**：
  - 关键词：`#if SPEEDYNOTE_ENABLE_POPPLER`、`Poppler::Document`。
  - 查看差异：`git diff 3016747..HEAD -- source/InkCanvas.h`

---

## source/InkCanvas.cpp（修改）
- **新增宏守卫**：大量 PDF 相关逻辑以 `SPEEDYNOTE_ENABLE_POPPLER` 包裹。
- **加载/清理**：
  - `loadPdf()`：在关闭 Poppler 时清空缓存/状态，发出 `pdfLoaded()` 但不加载文档。
  - `clearPdf()`/`clearPdfNoDelete()`：关闭 Poppler 时仅重置状态与缓存。
- **页面渲染/缓存**：
  - `loadPdfPage()`/`renderPdfPageToCache()`/`checkAndCacheAdjacentPages()`：在关闭 Poppler 时退化为清空背景图并 `update()`。
  - `loadPdfPreviewAsync()`：关闭 Poppler 时为 no-op。
- **绘制层**：
  - `paintEvent()` 中 PDF 文本选择覆盖层仅在开启 Poppler 时渲染。
- **文本选择子系统**：
  - 开启 Poppler：保留完整逻辑（选框/映射/菜单等）。
  - 关闭 Poppler：提供空实现与状态复位（`clearPdfTextSelection()` 等）。
- **快速定位**：
  - 关键词：`#if SPEEDYNOTE_ENABLE_POPPLER`、`pdfTextSelection`、`renderPdfPageToCache`。
  - 查看差异：`git diff 3016747..HEAD -- source/InkCanvas.cpp`

---

## source/Main.cpp（修改）
- **新增宏守卫**：`SPEEDYNOTE_ENABLE_SDL`。
- **启动阶段**：
  - 仅在启用 SDL 时设置 `SDL_SetHint` 并 `SDL_Init(SDL_INIT_GAMECONTROLLER | SDL_INIT_JOYSTICK)`。
- **快速定位**：
  - 关键词：`#if SPEEDYNOTE_ENABLE_SDL`、`SDL_Init`。
  - 查看差异：`git diff 3016747..HEAD -- source/Main.cpp`

---

## source/MainWindow.h（修改）
- **新增宏守卫**：`SPEEDYNOTE_ENABLE_POPPLER` 包裹 `Poppler::Document`、`OutlineItem` 前向声明与相关私有方法：
  - `addOutlineItem(...)`、`getPdfDocument()`。
- **快速定位**：
  - 关键词：`#if SPEEDYNOTE_ENABLE_POPPLER`、`addOutlineItem`。
  - 查看差异：`git diff 3016747..HEAD -- source/MainWindow.h`

---

## source/MainWindow.cpp（修改）
- **交互与反馈**：
  - 将拨轮震动（SDL rumble）与提示音（SimpleAudio）分别以 `SPEEDYNOTE_ENABLE_SDL`、`SPEEDYNOTE_ENABLE_AUDIO` 宏控制：
    - `initializeDialSound()`、`handleToolSelection()`、`onPanScrollReleased()` 等处增加条件编译与 `Q_UNUSED` 处理。
- **PDF 目录（Outline）**：
  - `loadPdfOutline()`/`addOutlineItem(...)`/`getPdfDocument()` 在 `SPEEDYNOTE_ENABLE_POPPLER` 下有效；关闭时清空 UI 并跳过解析。
- **其他**：
  - 拨轮行为中预览页面加载（`loadPdfPreviewAsync`）逻辑保持，条件编译范围内移动 rumble/音效调用。
- **快速定位**：
  - 关键词：`SPEEDYNOTE_ENABLE_SDL`、`SPEEDYNOTE_ENABLE_AUDIO`、`SPEEDYNOTE_ENABLE_POPPLER`、`loadPdfOutline`、`SDL_JoystickRumble`。
  - 查看差异：`git diff 3016747..HEAD -- source/MainWindow.cpp`

---

## source/SDLControllerManager.h（修改）
- **新增宏守卫**：`SPEEDYNOTE_ENABLE_SDL`；当禁用时以前向声明 `struct SDL_Joystick;` 代替头文件。
- **接口签名**：`getButtonName` / `getLogicalButtonName` 的参数从 `Uint8` 改为 `int`，避免无 SDL 头时的类型依赖。
- **新增包含**：`#include <QStringList>`。
- **快速定位**：
  - 关键词：`#if SPEEDYNOTE_ENABLE_SDL`、`struct SDL_Joystick`、`QStringList`。
  - 查看差异：`git diff 3016747..HEAD -- source/SDLControllerManager.h`

---

## source/SDLControllerManager.cpp（修改）
- **宏守卫**：
  - SDL 启用：保留实装，并将轮询刷新频率由魔数改为常量 `POLL_INTERVAL`。
  - SDL 关闭：提供空实现（start/stop/reconnect 等），保留映射读写逻辑（QSettings）与查询接口，保证上层不崩溃。
- **日志清理**：去除大量调试输出（`qDebug()`）。
- **快速定位**：
  - 关键词：`#if SPEEDYNOTE_ENABLE_SDL`、`POLL_INTERVAL`、`saveControllerMappings`、`loadControllerMappings`。
  - 查看差异：`git diff 3016747..HEAD -- source/SDLControllerManager.cpp`

---

## source/SimpleAudio.h / .cpp（修改）
- **新增宏守卫**：`SPEEDYNOTE_ENABLE_AUDIO`。
- **平台分支**：
  - Linux 上排除 Android 的 ALSA 分支：`#elif defined(__linux__) && !defined(__ANDROID__)`。
- **禁用时的降级实现**：
  - 保留类接口但实现为空，`isAudioAvailable()` 返回 `false`，并维护可设置的 `volume`/`minimumInterval`。
- **快速定位**：
  - 关键词：`#if SPEEDYNOTE_ENABLE_AUDIO`、`!defined(__ANDROID__)`、`SimpleAudioPrivate`。
  - 查看差异：`git diff 3016747..HEAD -- source/SimpleAudio.h source/SimpleAudio.cpp`

---

## README.md（修改）
- **新增 Android 构建说明**：在 Docker/容器中使用 `build-android.sh`，并说明启用 Poppler 的参数与 APK 输出位置。
- **快速定位**：`git diff 3016747..HEAD -- README.md`

---

## 附：开发者导航命令
- **提交图**：`git log --oneline --decorate --graph 3016747..HEAD`
- **单文件差异**：`git diff -U3 3016747..HEAD -- <path>`
- **定位关键词**：
  - `git grep -n "SPEEDYNOTE_ENABLE_POPPLER|SPEEDYNOTE_ENABLE_SDL|SPEEDYNOTE_ENABLE_AUDIO"`
  - `git grep -n "pkg_check_modules(POPPLER_QT6|PKG_CONFIG_USE_STATIC_LIBS|qt_add_executable|qt_finalize_executable"`

