cmake_minimum_required(VERSION 3.25.0 FATAL_ERROR)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Keep the historical CMake project/target identifier for compatibility with
# upstream build scripts while exposing TunnelCore VPN as the product brand.
set(PROJECT AmneziaVPN)

# Local/release fallback stays stable. GitHub Actions test builds automatically
# use 5.0.2.<run_number>, so every produced package can be identified uniquely.
if(NOT AMNEZIAVPN_VERSION)
    if(DEFINED ENV{GITHUB_RUN_NUMBER} AND NOT "$ENV{GITHUB_RUN_NUMBER}" STREQUAL "")
        set(AMNEZIAVPN_VERSION "5.0.2.$ENV{GITHUB_RUN_NUMBER}" CACHE STRING "Client app version")
    else()
        set(AMNEZIAVPN_VERSION 5.0.2.2 CACHE STRING "Client app version")
    endif()
endif()

set(QT_CREATOR_SKIP_PACKAGE_MANAGER_SETUP ON CACHE BOOL "" FORCE)
set(CMAKE_PROJECT_TOP_LEVEL_INCLUDES
    ${CMAKE_SOURCE_DIR}/cmake/platform_settings.cmake
    ${CMAKE_SOURCE_DIR}/cmake/recipes_bootstrap.cmake
    ${CMAKE_SOURCE_DIR}/cmake/conan_provider.cmake
    CACHE STRING "" FORCE)

project(${PROJECT} VERSION ${AMNEZIAVPN_VERSION}
        DESCRIPTION "TunnelCore VPN"
        HOMEPAGE_URL "https://github.com/VnextDevelopment/tunnelcore-vpn"
)

# trigger conan to kick off `conan install` globally
find_package(OpenSSL REQUIRED)
if (PREBUILTS_ONLY)
    return()
endif()

string(TIMESTAMP CURRENT_DATE "%Y-%m-%d")
set(RELEASE_DATE "${CURRENT_DATE}")

set(APP_MAJOR_VERSION ${CMAKE_PROJECT_VERSION_MAJOR}.${CMAKE_PROJECT_VERSION_MINOR}.${CMAKE_PROJECT_VERSION_PATCH})

# Keep Android versionCode unique as well. The two Play Store variants use
# offsets 0/1, so multiplying the workflow run number by 2 leaves room for both.
if(DEFINED ENV{GITHUB_RUN_NUMBER} AND NOT "$ENV{GITHUB_RUN_NUMBER}" STREQUAL "")
    math(EXPR APP_ANDROID_VERSION_CODE "2161000 + ($ENV{GITHUB_RUN_NUMBER} * 2)")
else()
    set(APP_ANDROID_VERSION_CODE 2161)
endif()
if(DEFINED APP_ANDROID_VERSION_CODE_OFFSET)
    math(EXPR APP_ANDROID_VERSION_CODE "${APP_ANDROID_VERSION_CODE} + ${APP_ANDROID_VERSION_CODE_OFFSET}")
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(MZ_PLATFORM_NAME "linux")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
    set(MZ_PLATFORM_NAME "windows")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
    set(MZ_PLATFORM_NAME "macos")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Android")
    set(MZ_PLATFORM_NAME "android")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
    set(MZ_PLATFORM_NAME "ios")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Emscripten")
    set(MZ_PLATFORM_NAME "wasm")
endif()

set(QT_BUILD_TOOLS_WHEN_CROSS_COMPILING ON)

if(APPLE AND NOT IOS)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(AMN_PF_RULE_IDENTITY "user { root }")
    else()
        set(AMN_PF_RULE_IDENTITY "group { amnvpn }")
    endif()

    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/deploy/data/pf-templates/amn.400.allowPIA.conf.in"
        "${CMAKE_CURRENT_BINARY_DIR}/amn.400.allowPIA.conf"
        @ONLY
    )

    file(COPY_FILE
        "${CMAKE_CURRENT_BINARY_DIR}/amn.400.allowPIA.conf"
        "${CMAKE_CURRENT_SOURCE_DIR}/deploy/data/macos/pf/amn.400.allowPIA.conf"
        ONLY_IF_DIFFERENT
    )
endif()


add_subdirectory(client)

if(NOT IOS AND NOT ANDROID AND NOT MACOS_NE)
    add_subdirectory(service)
endif()

if ((LINUX AND NOT ANDROID) OR (APPLE AND NOT IOS AND NOT MACOS_NE) OR (WIN32))
    include(${CMAKE_SOURCE_DIR}/cmake/CPack.cmake)
endif()
