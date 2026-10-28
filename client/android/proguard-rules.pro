# Release R8 rules for the Qt/C++ Android client.
# Do not keep the entire app package: Google Play needs actual DEX shrinking
# and obfuscation, but the dynamically resolved JNI boundary must stay stable.

# Qt Android uses reflection/JNI and class names loaded from native Qt code.
-keep class org.qtproject.qt.** { *; }

# C++ calls Activity methods by their original names/signatures via QJniObject.
-keep class org.amnezia.vpn.AmneziaActivity { *; }

# AndroidController registers these native methods using exact JNI strings.
-keep class org.amnezia.vpn.qt.QtAndroidController { *; }

# C++ obtains the logger by name and caches its method IDs.
-keep class org.amnezia.vpn.util.Log { *; }

# SWIG's OpenVPN Java classes are paired with native symbols and lookups.
-keep class net.openvpn.ovpn3.** { *; }

# Preserve native method names and owning classes for other JNI entry points.
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep metadata used by Kotlin serialization and other runtime libraries.
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
