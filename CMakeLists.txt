cmake_minimum_required(VERSION 3.10)
cmake_policy(SET CMP0074 NEW)

project(NoteApp)
set(CMAKE_CXX_STANDARD 17)

# Using variable
set(QT_PATH "C:/Qt/6.9.2/mingw_64" CACHE PATH "Path to Qt installation")
set(SDL2_ROOT "C:/msys64/mingw64" CACHE PATH "Path to SDL2")
set(POPPLER_PATH "C:/msys64/mingw64" CACHE PATH "Path to Poppler")
# This is where the "libpoppler-qt6-dev" equivalent in Windows is located. 
# Go to the MSYS2 terminal to run this commands:
# pacman -S mingw-w64-x86_64-poppler-qt6

set(_speedynote_poppler_default ON)
set(_speedynote_sdl_default ON)
set(_speedynote_audio_default ON)
if (ANDROID)
    set(_speedynote_poppler_default OFF)
    set(_speedynote_sdl_default OFF)
    set(_speedynote_audio_default OFF)
endif()

option(SPEEDYNOTE_ENABLE_POPPLER "Enable Poppler PDF features" ${_speedynote_poppler_default})
option(SPEEDYNOTE_ENABLE_SDL "Enable SDL-based controller features" ${_speedynote_sdl_default})
option(SPEEDYNOTE_ENABLE_AUDIO "Enable custom audio playback" ${_speedynote_audio_default})

set(SPEEDYNOTE_POPPLER_SYSROOT "" CACHE PATH "Optional: Poppler install prefix for Android cross-builds")

if (ANDROID AND SPEEDYNOTE_ENABLE_POPPLER)
    if (SPEEDYNOTE_POPPLER_SYSROOT)
        if (NOT EXISTS "${SPEEDYNOTE_POPPLER_SYSROOT}")
            message(WARNING "SPEEDYNOTE_POPPLER_SYSROOT='${SPEEDYNOTE_POPPLER_SYSROOT}' does not exist.")
        else()
            list(APPEND CMAKE_PREFIX_PATH "${SPEEDYNOTE_POPPLER_SYSROOT}")
            list(APPEND CMAKE_FIND_ROOT_PATH "${SPEEDYNOTE_POPPLER_SYSROOT}")
        endif()
    else()
        message(WARNING "SPEEDYNOTE_ENABLE_POPPLER=ON but SPEEDYNOTE_POPPLER_SYSROOT is not set. Set it to your Poppler Android install prefix.")
    endif()
endif()

# Also, there isn't such thing called PopplerConfig.cmake. 
#That's why I need to make a FindPoppler.cmake file

# ✅ Platform-specific configuration
if (WIN32)
    # ✅ Platform-specific configuration
    
    set(CMAKE_PREFIX_PATH
            "${QT_PATH}/lib/cmake"
            "${SDL2_ROOT}/lib/cmake"
    )
    set(CMAKE_MODULE_PATH "${QT_PATH}/lib/cmake/Poppler")
    # In my case, this path is C:\Qt\6.9.2\mingw_64\lib\cmake\Poppler. 
    # This path includes the FindPoppler.cmake file. 
    # You need to manually put FindPoppler.cmake into this folder.

    include_directories(
            # "${POPPLER_PATH}/include/poppler"
            # "${POPPLER_PATH}/include/poppler/cpp" In fact, these 2 paths are poppler and poppler-cpp, which are different from poppler-qt6.
            "${POPPLER_PATH}/include/poppler/qt6"
            "${SDL2_ROOT}/include"
            ${CMAKE_CURRENT_BINARY_DIR}
    )
    link_directories("${POPPLER_PATH}/lib")

    # Prevent SDL2 from redefining main()
    add_compile_definitions(SDL_MAIN_HANDLED)

    # Enable modern instruction sets and optimizations for Windows
    add_compile_options(
        -march=haswell          # Enable AVX2, FMA, BMI1, BMI2 instructions
        -mtune=haswell          # Optimize for Haswell+ architectures
        -mavx2                  # Explicitly enable AVX2
        -mfma                   # Enable FMA (Fused Multiply-Add)
        -mbmi                   # Enable BMI1 (Bit Manipulation Instructions)
        -mbmi2                  # Enable BMI2
        -O3                     # Maximum optimization level
        -DNDEBUG                # Disable debug assertions for performance
    )

    # Windows resource file
    enable_language(RC)
    set(WIN_RESOURCES app_icon.rc)

    # Find dependencies for Windows
    find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Concurrent Xml Network)
    if (SPEEDYNOTE_ENABLE_POPPLER)
        find_package(Poppler REQUIRED)
    endif()
    if (SPEEDYNOTE_ENABLE_SDL)
        find_package(SDL2 REQUIRED CONFIG)
        unset(SDL2main CACHE)
    endif()
elseif (ANDROID)
    find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Concurrent Xml Network)
    include_directories(${CMAKE_CURRENT_BINARY_DIR})
    if (SPEEDYNOTE_ENABLE_POPPLER)
        list(APPEND CMAKE_FIND_ROOT_PATH "${SPEEDYNOTE_POPPLER_SYSROOT}")
        set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
        set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)

        set(PKG_CONFIG_USE_STATIC_LIBS ON)
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(POPPLER_QT6 REQUIRED IMPORTED_TARGET poppler-qt6)
        pkg_check_modules(POPPLER_CORE REQUIRED IMPORTED_TARGET poppler)
        set(ANDROID_POPPLER_STATIC_LIBS
            ${POPPLER_QT6_STATIC_LIBRARIES}
            ${POPPLER_QT6_LIBRARIES}
            ${POPPLER_CORE_STATIC_LIBRARIES}
            ${POPPLER_CORE_LIBRARIES}
        )
        list(REMOVE_DUPLICATES ANDROID_POPPLER_STATIC_LIBS)

        set(ANDROID_POPPLER_LIBRARY_DIRS
            ${POPPLER_QT6_LIBRARY_DIRS}
            ${POPPLER_CORE_LIBRARY_DIRS}
        )
        list(REMOVE_DUPLICATES ANDROID_POPPLER_LIBRARY_DIRS)

        set(ANDROID_POPPLER_LINK_FLAGS
            ${POPPLER_QT6_STATIC_LDFLAGS}
            ${POPPLER_QT6_STATIC_LDFLAGS_OTHER}
            ${POPPLER_QT6_LDFLAGS}
            ${POPPLER_QT6_LDFLAGS_OTHER}
            ${POPPLER_CORE_STATIC_LDFLAGS}
            ${POPPLER_CORE_STATIC_LDFLAGS_OTHER}
            ${POPPLER_CORE_LDFLAGS}
            ${POPPLER_CORE_LDFLAGS_OTHER}
        )
        list(REMOVE_DUPLICATES ANDROID_POPPLER_LINK_FLAGS)

        set(ANDROID_POPPLER_INCLUDE_DIRS
            ${POPPLER_QT6_INCLUDE_DIRS}
            ${POPPLER_CORE_INCLUDE_DIRS}
        )
        list(REMOVE_DUPLICATES ANDROID_POPPLER_INCLUDE_DIRS)

        list(APPEND ANDROID_POPPLER_STATIC_LIBS
            lcms2
            png
            jpeg
            openjp2
            tiff
            z
            freetype
        )
        list(REMOVE_DUPLICATES ANDROID_POPPLER_STATIC_LIBS)
    endif()
    set(WIN_RESOURCES "")
elseif (UNIX)
    # Linux-specific configuration
    # Use system paths for Linux
    find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Concurrent Xml Network)

    if (SPEEDYNOTE_ENABLE_POPPLER OR SPEEDYNOTE_ENABLE_SDL)
        find_package(PkgConfig REQUIRED)
    endif()
    if (SPEEDYNOTE_ENABLE_POPPLER)
        pkg_check_modules(POPPLER REQUIRED IMPORTED_TARGET poppler-qt6)
    endif()
    if (SPEEDYNOTE_ENABLE_SDL)
        pkg_check_modules(SDL2 REQUIRED IMPORTED_TARGET sdl2)
    endif()

    # Include current binary directory for generated files
    include_directories(${CMAKE_CURRENT_BINARY_DIR})

    # No Windows-specific resources
    set(WIN_RESOURCES "")
endif ()

# Translation files
set(TS_FILES
        ${CMAKE_SOURCE_DIR}/resources/translations/app_zh.ts
        ${CMAKE_SOURCE_DIR}/resources/translations/app_es.ts
        ${CMAKE_SOURCE_DIR}/resources/translations/app_fr.ts
)

# ✅ Enable Qt automatic features
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# ✅ QMarkdownTextEdit sources
set(QMARKDOWNTEXTEDIT_SOURCES
        markdown/qmarkdowntextedit.cpp
        markdown/markdownhighlighter.cpp
        markdown/qownlanguagedata.cpp
        markdown/qplaintexteditsearchwidget.cpp
)

set(QMARKDOWNTEXTEDIT_HEADERS
        markdown/qmarkdowntextedit.h
        markdown/markdownhighlighter.h
        markdown/qownlanguagedata.h
        markdown/qplaintexteditsearchwidget.h
        markdown/linenumberarea.h
)

# Process headers that contain Q_OBJECT for MOC
qt6_wrap_cpp(QMARKDOWNTEXTEDIT_MOC_SOURCES markdown/linenumberarea.h)

set(QMARKDOWNTEXTEDIT_UI
        markdown/qplaintexteditsearchwidget.ui
)

set(QMARKDOWNTEXTEDIT_RESOURCES
        markdown/media.qrc
)

# Process UI files to generate headers
qt6_wrap_ui(QMARKDOWNTEXTEDIT_UI_HEADERS ${QMARKDOWNTEXTEDIT_UI})

# ✅ Resources
set(RESOURCES resources.qrc ${QMARKDOWNTEXTEDIT_RESOURCES})
QT6_ADD_RESOURCES(QRCC_FILES ${RESOURCES})

# ✅ Build target
qt_add_executable(${PROJECT_NAME}
        source/Main.cpp
        source/MainWindow.cpp
        source/InkCanvas.cpp
        source/SimpleAudio.cpp
        source/ControlPanelDialog.cpp
        source/SDLControllerManager.cpp
        source/ButtonMappingTypes.cpp
        source/RecentNotebooksManager.cpp
        source/KeyCaptureDialog.cpp
        source/ControllerMappingDialog.cpp
        source/MarkdownWindow.cpp
        source/MarkdownWindowManager.cpp
	  source/PictureWindow.cpp
    	  source/PictureWindowManager.cpp
        source/PdfOpenDialog.cpp
	  source/PdfRelinkDialog.cpp
    	  source/SpnPackageManager.cpp
    	  source/LauncherWindow.cpp
        ${QRCC_FILES}
        ${QMARKDOWNTEXTEDIT_SOURCES}
        ${QMARKDOWNTEXTEDIT_UI_HEADERS}
        ${QMARKDOWNTEXTEDIT_MOC_SOURCES}
        ${WIN_RESOURCES}
)

# ✅ Compile .ts → .qm using Qt's lrelease
find_program(LRELEASE_EXECUTABLE
        lrelease
        PATHS "${QT_PATH}/bin"
        NO_DEFAULT_PATH
)
if (WIN32)
    find_program(LRELEASE_EXECUTABLE lrelease PATHS "C:/Qt/6.9.2/mingw_64/bin")
endif ()

if (LRELEASE_EXECUTABLE)
    foreach (_ts ${TS_FILES})
        get_filename_component(_qm ${_ts} NAME_WE)
        set(_qm_file ${CMAKE_CURRENT_BINARY_DIR}/${_qm}.qm)
        add_custom_command(
                OUTPUT ${_qm_file}
                COMMAND ${LRELEASE_EXECUTABLE} ${_ts} -qm ${_qm_file}
                DEPENDS ${_ts}
                COMMENT "Generating ${_qm_file}"
                VERBATIM
        )
        list(APPEND QM_FILES ${_qm_file})
    endforeach ()

    # Add a target to build translations
    add_custom_target(translations ALL DEPENDS ${QM_FILES})
endif ()

# Disable Qt deprecated warnings
add_compile_definitions(QT_NO_DEPRECATED_WARNINGS)

target_compile_definitions(${PROJECT_NAME} PRIVATE
        SPEEDYNOTE_ENABLE_POPPLER=$<IF:$<BOOL:${SPEEDYNOTE_ENABLE_POPPLER}>,1,0>
        SPEEDYNOTE_ENABLE_SDL=$<IF:$<BOOL:${SPEEDYNOTE_ENABLE_SDL}>,1,0>
        SPEEDYNOTE_ENABLE_AUDIO=$<IF:$<BOOL:${SPEEDYNOTE_ENABLE_AUDIO}>,1,0>
)

# ✅ Link libraries - platform specific
if (WIN32)
    target_link_libraries(NoteApp PRIVATE
            Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Concurrent Qt6::Xml Qt6::Network)
    if (SPEEDYNOTE_ENABLE_SDL)
        target_link_libraries(NoteApp PRIVATE SDL2::SDL2)
    endif()
    if (SPEEDYNOTE_ENABLE_POPPLER)
        target_link_libraries(NoteApp PRIVATE ${POPPLER_LIBRARIES})
    endif()
    if (SPEEDYNOTE_ENABLE_AUDIO)
        target_link_libraries(NoteApp PRIVATE
                dsound  # For DirectSound API
                dxguid  # For DirectSound GUIDs
        )
    endif()
elseif (ANDROID)
    target_link_libraries(NoteApp PRIVATE
            Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Concurrent Qt6::Xml Qt6::Network)
    if (SPEEDYNOTE_ENABLE_POPPLER)
        target_include_directories(NoteApp PRIVATE ${ANDROID_POPPLER_INCLUDE_DIRS})
        target_link_directories(NoteApp PRIVATE ${ANDROID_POPPLER_LIBRARY_DIRS})
        target_link_options(NoteApp PRIVATE ${ANDROID_POPPLER_LINK_FLAGS})
        target_link_libraries(NoteApp PRIVATE ${ANDROID_POPPLER_STATIC_LIBS})
        target_link_libraries(NoteApp PRIVATE
                lcms::lcms
                libjpeg-turbo::libjpeg-turbo
                TIFF::TIFF
                Freetype::Freetype
                PNG::PNG
                ZLIB::ZLIB
                openjp2)
    endif()
elseif (UNIX)
    target_link_libraries(NoteApp PRIVATE
            Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Concurrent Qt6::Xml Qt6::Network)
    if (SPEEDYNOTE_ENABLE_SDL)
        target_link_libraries(NoteApp PRIVATE PkgConfig::SDL2)
    endif()
    if (SPEEDYNOTE_ENABLE_POPPLER)
        target_link_libraries(NoteApp PRIVATE PkgConfig::POPPLER)
    endif()
    if (SPEEDYNOTE_ENABLE_AUDIO)
        target_link_libraries(NoteApp PRIVATE
                asound  # For ALSA audio
        )
    endif()
endif ()

qt_finalize_executable(${PROJECT_NAME})

# ✅ Set output name for Linux
if (UNIX AND NOT ANDROID)
    set_target_properties(NoteApp PROPERTIES OUTPUT_NAME NoteApp)
endif ()

# ✅ Install targets for Linux/Flatpak
if (UNIX AND NOT ANDROID)
    # Install the main executable
    install(TARGETS NoteApp DESTINATION bin)

    # Install translation files if they exist
    if (QM_FILES)
        install(FILES ${QM_FILES} DESTINATION share/speedynote/translations)
    endif ()
    
    # Also install resource translation files
    file(GLOB RESOURCE_QM_FILES "resources/translations/*.qm")
    if (RESOURCE_QM_FILES)
        install(FILES ${RESOURCE_QM_FILES} DESTINATION share/speedynote/translations)
    endif ()

    # Install icon with app ID name for proper Flatpak desktop integration
    install(FILES resources/icons/mainicon.png
            DESTINATION share/icons/hicolor/256x256/apps
            RENAME com.github.alpha_liu_01.SpeedyNote.png)

    # Install desktop file and metainfo (handled by Flatpak post-install)
endif ()
