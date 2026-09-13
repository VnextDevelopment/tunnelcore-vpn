if(NOT CLIENT_TARGET_NAME)
    set(CLIENT_TARGET_NAME "TunnelCoreVPN" CACHE STRING "Client executable target name")
endif()

if(NOT CLIENT_APPLICATION_NAME)
    set(CLIENT_APPLICATION_NAME "TunnelCore VPN" CACHE STRING "Application display name")
endif()

if(NOT CLIENT_SERVICE_NAME)
    # Service executable rename is handled separately from the display brand.
    set(CLIENT_SERVICE_NAME "AmneziaVPN-service" CACHE STRING "Service executable name")
endif()

if(NOT CLIENT_ORGANIZATION_NAME)
    set(CLIENT_ORGANIZATION_NAME "TunnelCore" CACHE STRING "QSettings organization name")
endif()

if(NOT CLIENT_APP_INSTANCE_NAME)
    set(CLIENT_APP_INSTANCE_NAME "TunnelCoreVPNInstance" CACHE STRING "Single-instance local server name")
endif()

if(NOT CLIENT_KEYCHAIN_NAME)
    set(CLIENT_KEYCHAIN_NAME "TunnelCoreVPN-Keychain" CACHE STRING "QtKeychain service name used for encrypted settings keys")
endif()
