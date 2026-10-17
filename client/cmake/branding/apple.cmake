if(NOT CLIENT_SWIFT_MODULE_NAME)
    set(CLIENT_SWIFT_MODULE_NAME "TunnelCoreVPN" CACHE STRING "Swift module name for Objective-C interop header")
endif()
if(NOT CLIENT_SWIFT_OBJC_HEADER_NAME)
    set(CLIENT_SWIFT_OBJC_HEADER_NAME "${CLIENT_SWIFT_MODULE_NAME}-Swift.h" CACHE STRING "Generated Swift Objective-C header name")
endif()
if(NOT CLIENT_NETWORK_EXTENSION_NAME)
    set(CLIENT_NETWORK_EXTENSION_NAME "TunnelCoreVPNNetworkExtension" CACHE STRING "Display name for Apple network extension targets")
endif()

# TunnelCore owns its Apple app IDs. Developer Team and signing profiles must
# be supplied by the account owner; never fall back to upstream Amnezia keys.
if(NOT BUILD_OSX_APP_IDENTIFIER)
    set(BUILD_OSX_APP_IDENTIFIER com.vnextdev.tunnelcorevpn.macos CACHE STRING "OSX Application identifier")
endif()
if(NOT BUILD_IOS_APP_IDENTIFIER)
    set(BUILD_IOS_APP_IDENTIFIER com.vnextdev.tunnelcorevpn CACHE STRING "iOS Application identifier")
endif()
if(NOT BUILD_IOS_GROUP_IDENTIFIER)
    set(BUILD_IOS_GROUP_IDENTIFIER group.com.vnextdev.tunnelcorevpn CACHE STRING "Shared Apple app group identifier")
endif()
if(NOT BUILD_VPN_DEVELOPMENT_TEAM)
    set(BUILD_VPN_DEVELOPMENT_TEAM "" CACHE STRING "TunnelCore Apple Developer Team ID (10 characters)")
endif()

# Do not allow a production build with somebody else's signing identity.
if(APPLE AND DEPLOY AND NOT BUILD_VPN_DEVELOPMENT_TEAM)
    message(FATAL_ERROR "Set BUILD_VPN_DEVELOPMENT_TEAM to your Apple Developer Team ID before signing TunnelCore VPN.")
endif()
