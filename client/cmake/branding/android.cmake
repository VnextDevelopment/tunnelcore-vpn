# Keep this in sync with applicationId in client/android/build.gradle.kts.
# The package name is reserved in Google Play Console and must remain stable.
if(NOT CLIENT_ANDROID_PACKAGE)
    set(CLIENT_ANDROID_PACKAGE "com.vnextdev.tunnelcorevpn" CACHE STRING "Android package name for Play Store version lookup")
endif()
