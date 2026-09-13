cmake_minimum_required(VERSION 3.25.0 FATAL_ERROR)

include(${CMAKE_CURRENT_LIST_DIR}/cmake/clientBrandingDefaults.cmake)

set(PROJECT ${CLIENT_TARGET_NAME})
project(${PROJECT})

set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY AUTOGEN_TARGETS_FOLDER "Autogen")
set_property(GLOBAL PROPERTY AUTOMOC_TARGETS_FOLDER "Autogen")
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "Autogen")

set(PACKAGES
    Core Gui Network Xml
    RemoteObjects Quick Svg QuickControls2
    Core5Compat Concurrent LinguistTools
)

execute_process(
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMAND git rev-parse --short HEAD
  OUTPUT_VARIABLE GIT_COMMIT_HASH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

add_definitions(-DGIT_COMMIT_HASH="${GIT_COMMIT_HASH}")

add_definitions(-DPROD_AGW_PUBLIC_KEY="$ENV{PROD_AGW_PUBLIC_KEY}")
add_definitions(-DPROD_S3_ENDPOINT="$ENV{PROD_S3_ENDPOINT}")
add_definitions(-DFALLBACK_S3_ENDPOINT="$ENV{FALLBACK_S3_ENDPOINT}")

add_definitions(-DDEV_AGW_PUBLIC_KEY="$ENV{DEV_AGW_PUBLIC_KEY}")
add_definitions(-DDEV_AGW_ENDPOINT="$ENV{DEV_AGW_ENDPOINT}")
add_definitions(-DDEV_S3_ENDPOINT="$ENV{DEV_S3_ENDPOINT}")

add_definitions(-DFREE_V2_ENDPOINT="$ENV{FREE_V2_ENDPOINT}")
add_definitions(-DPREM_V1_ENDPOINT="$ENV{PREM_V1_ENDPOINT}")

if(WIN32 OR (APPLE AND NOT IOS) OR (LINUX AND NOT ANDROID))
    set(PACKAGES ${PACKAGES} Widgets)
endif()

find_package(Qt6 REQUIRED COMPONENTS ${PACKAGES})
find_package(OpenSSL REQUIRED)

set(LIBS ${LIBS}
    Qt6::Core Qt6::Gui
    Qt6::Network Qt6::Xml Qt6::RemoteObjects
    Qt6::Quick Qt6::Svg Qt6::QuickControls2
    Qt6::Core5Compat Qt6::Concurrent
)

if(WIN32 OR (APPLE AND NOT IOS) OR (LINUX AND NOT ANDROID))
    set(LIBS ${LIBS} Qt6::Widgets)
endif()

qt_standard_project_setup()
qt_add_executable(${PROJECT} MANUAL_FINALIZATION)
target_include_directories(${PROJECT} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
)
target_compile_definitions(${PROJECT} PRIVATE
    CLIENT_KEYCHAIN_NAME_STR=\"${CLIENT_KEYCHAIN_NAME}\"
)

if(WIN32 OR (APPLE AND NOT IOS AND NOT MACOS_NE) OR (LINUX AND NOT ANDROID))
    qt_add_repc_replicas(${PROJECT} ${CMAKE_CURRENT_LIST_DIR}/../ipc/ipc_interface.rep)
    qt_add_repc_replicas(${PROJECT} ${CMAKE_CURRENT_LIST_DIR}/../ipc/ipc_process_interface.rep)
endif()

qt6_add_resources(QRC ${QRC}
    ${CMAKE_CURRENT_LIST_DIR}/images/images.qrc
    ${CMAKE_CURRENT_LIST_DIR}/images/flagKit.qrc
    ${CMAKE_CURRENT_LIST_DIR}/client_scripts/clientScripts.qrc
    ${CLIENT_QML_QRC_FILE}
    ${CMAKE_CURRENT_LIST_DIR}/server_scripts/serverScripts.qrc
    ${CLIENT_EXTRA_QRC}
)

# -- i18n begin
if(CLIENT_TS_FILES)
    set(AMNEZIAVPN_TS_FILES ${CLIENT_TS_FILES})
else()
    set(AMNEZIAVPN_TS_FILES
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_ru_RU.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_zh_CN.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_fa_IR.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_ar_EG.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_my_MM.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_uk_UA.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_ur_PK.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_hi_IN.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_es_ES.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_ko_KR.ts
        ${CMAKE_CURRENT_LIST_DIR}/translations/${CLIENT_TS_PREFIX}_fr_FR.ts
    )
endif()

file(GLOB_RECURSE AMNEZIAVPN_QML_FILES ${CMAKE_CURRENT_LIST_DIR}/ui/qml/*.qml)

qt6_add_translations(${PROJECT}
    TS_FILES ${AMNEZIAVPN_TS_FILES}
    SOURCES ${AMNEZIAVPN_QML_FILES}
    RESOURCE_PREFIX "/translations"
)
# -- i18n end

set(IS_CI ${CI})
if(IS_CI)
    message("Detected CI env")
    find_program(CCACHE "ccache")
    if(CCACHE)
        set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${CCACHE}")
    endif()
endif()

include(${CMAKE_CURRENT_LIST_DIR}/cmake/3rdparty.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/sources.cmake)

set(_client_include_dirs
    ${CMAKE_CURRENT_LIST_DIR}/../ipc
    ${CMAKE_CURRENT_LIST_DIR}/../common/logger
    ${CMAKE_CURRENT_LIST_DIR}/../common/crypto
    ${CMAKE_CURRENT_LIST_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
)
if(CLIENT_BRANDING_INCLUDE_DIR)
    list(APPEND _client_include_dirs ${CLIENT_BRANDING_INCLUDE_DIR})
endif()
list(APPEND _client_include_dirs ${CMAKE_CURRENT_LIST_DIR})
include_directories(${_client_include_dirs})

if(MACOS_NE)
    message("MACOS_NE is ON")
    add_definitions(-DQ_OS_MAC)
    add_definitions(-DMACOS_NE)
    message("Add macros for MacOS Network Extension")
else()
    message("MACOS_NE is OFF")
endif()

include_directories(mozilla)
include_directories(mozilla/shared)
include_directories(mozilla/models)

configure_file(${CMAKE_CURRENT_LIST_DIR}/../version.h.in ${CMAKE_CURRENT_BINARY_DIR}/version.h)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/core/utils)
configure_file(
    ${CMAKE_CURRENT_LIST_DIR}/core/utils/appUiConfig.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/core/utils/appUiConfig.h
    @ONLY
)
configure_file(
    ${CMAKE_CURRENT_LIST_DIR}/core/utils/swiftBridgeConfig.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/core/utils/swiftBridgeConfig.h
    @ONLY
)
# Swift can't consume a `-DGROUP_ID="value"` compile define (Swift -D flags are
# presence-only), unlike the Objective-C++ sources that read GROUP_ID directly.
# Generate a Swift constant instead so Log.swift can use the branded app group.
set(CLIENT_GROUP_IDENTIFIER_SWIFT_FILE ${CMAKE_CURRENT_BINARY_DIR}/platforms/ios/GroupIdentifier.swift)
configure_file(
    ${CMAKE_CURRENT_LIST_DIR}/platforms/ios/GroupIdentifier.swift.in
    ${CLIENT_GROUP_IDENTIFIER_SWIFT_FILE}
    @ONLY
)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_definitions(${PROJECT} PRIVATE "MZ_DEBUG")
endif()

if(WIN32)
    set(CLIENT_WINDOWS_ICON_FILE "${CMAKE_CURRENT_BINARY_DIR}/tunnelcore.ico")
    execute_process(
        COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_LIST_DIR}/platforms/windows/generate-tunnelcore-icon.ps1"
            -Source "${CMAKE_SOURCE_DIR}/IMG_5278.jpeg"
            -Output "${CLIENT_WINDOWS_ICON_FILE}"
        RESULT_VARIABLE TUNNELCORE_ICON_RESULT
    )
    if(NOT TUNNELCORE_ICON_RESULT EQUAL 0 OR NOT EXISTS "${CLIENT_WINDOWS_ICON_FILE}")
        message(FATAL_ERROR "Failed to generate TunnelCore Windows icon")
    endif()

    configure_file(
        ${CMAKE_CURRENT_LIST_DIR}/platforms/windows/amneziavpn.rc.in
        ${CMAKE_CURRENT_BINARY_DIR}/amneziavpn.rc
        @ONLY
    )

    set(LIBS ${LIBS}
        user32
        rasapi32
        shlwapi
        iphlpapi
        ws2_32
        gdi32
    )

    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup")
endif()

if(APPLE)
    cmake_policy(SET CMP0099 NEW)
    cmake_policy(SET CMP0114 NEW)


    set(CMAKE_XCODE_GENERATE_SCHEME FALSE)
    set(CMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM ${BUILD_VPN_DEVELOPMENT_TEAM})
    set(CMAKE_XCODE_ATTRIBUTE_GROUP_ID_IOS ${BUILD_IOS_GROUP_IDENTIFIER})
    
    if (BUILD_VPN_KEYCHAIN)
        set(CMAKE_XCODE_ATTRIBUTE_OTHER_CODE_SIGN_FLAGS "--keychain ${BUILD_VPN_KEYCHAIN}")
    endif()
endif()

if(LINUX AND NOT ANDROID)
    set(LIBS ${LIBS} -static-libstdc++ -static-libgcc -ldl)
    link_directories(${CMAKE_CURRENT_LIST_DIR}/platforms/linux)
    set(LIBS ${LIBS} -Wl,--no-as-needed $<TARGET_LINKER_FILE:Qt6::RemoteObjects> -Wl,--as-needed)
endif()

if(WIN32 OR (APPLE AND NOT IOS AND NOT MACOS_NE) OR (LINUX AND NOT ANDROID))
    add_compile_definitions(AMNEZIA_DESKTOP)
endif()

if(ANDROID)
    include(cmake/android.cmake)
endif()

if(IOS)
    include(cmake/ios.cmake)
    include(cmake/ios-arch-fixup.cmake)
elseif(APPLE AND MACOS_NE)
    include(cmake/macos_ne.cmake)
elseif(APPLE)
    include(cmake/osxtools.cmake)
    include(cmake/macos.cmake)
endif()

list(APPEND SOURCES ${CMAKE_CURRENT_LIST_DIR}/main.cpp)

target_link_libraries(${PROJECT} PRIVATE ${LIBS})
target_compile_definitions(${PROJECT} PRIVATE "MZ_$<UPPER_CASE:${MZ_PLATFORM_NAME}>")

target_sources(${PROJECT} PRIVATE ${SOURCES} ${HEADERS} ${RESOURCES} ${QRC} ${I18NQRC})

# Finalize the executable so Qt can gather/deploy QML modules and plugins correctly (Android needs this).
if(COMMAND qt_import_qml_plugins)
    qt_import_qml_plugins(${PROJECT})
endif()
if(COMMAND qt_finalize_executable)
    qt_finalize_executable(${PROJECT})
else()
    qt_finalize_target(${PROJECT})
endif()

install(TARGETS ${PROJECT}
    DESTINATION ${CMAKE_INSTALL_BINDIR}
    RUNTIME_DEPENDENCY_SET client_deps
    COMPONENT AmneziaVPN
)

if(APPLE)
    set(RUNTIME_DEPS_DIR ${CMAKE_INSTALL_BINDIR}/AmneziaVPN.app/Contents/Frameworks)
else()
    set(RUNTIME_DEPS_DIR ${CMAKE_INSTALL_BINDIR})
endif()

install(RUNTIME_DEPENDENCY_SET client_deps
    PRE_EXCLUDE_REGEXES
        [[api-ms-win-.*]]
        [[ext-ms-.*]]
    POST_EXCLUDE_REGEXES
        [[.*[\\/]system32[\\/].*\.dll]]
        [[.*[\\/]SysWOW64[\\/].*\.dll]]
        [[.*[\\/]Windows[\\/]WinSxS[\\/].*\.dll]]
)
