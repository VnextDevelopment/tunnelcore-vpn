"""Android Play R8 and Android TV visibility guardrails.

Static checks protect the fragile JNI boundary and keep split tunneling on
phones while removing TV entry points; full behavior still needs device tests.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ANDROID = ROOT / "client/android"
QML = ROOT / "client/ui/qml/Pages2"


class AndroidReleaseAndTvVisibilityTest(unittest.TestCase):
    def test_play_release_enables_r8_and_resource_shrinking(self):
        gradle = (ANDROID / "build.gradle.kts").read_text()
        self.assertIn("isMinifyEnabled = true", gradle)
        self.assertIn("isShrinkResources = true", gradle)
        self.assertIn('proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', gradle)
        rules = (ANDROID / "proguard-rules.pro").read_text()
        for anchor in ("org.qtproject.qt.**", "org.amnezia.vpn.AmneziaActivity",
                       "org.amnezia.vpn.qt.QtAndroidController",
                       "org.amnezia.vpn.util.Log", "net.openvpn.ovpn3.**",
                       "native <methods>"):
            with self.subTest(anchor=anchor):
                self.assertIn(anchor, rules)
        self.assertNotIn("-keep class org.amnezia.vpn.**", rules)

    def test_tv_split_is_hidden_on_home_and_in_connection_settings(self):
        account = (QML / "PageTunnelCoreAccount.qml").read_text()
        settings = (QML / "PageSettingsConnection.qml").read_text()
        start = (QML / "PageStart.qml").read_text()
        self.assertIn('objectName: "accountSplitTunnelingButton"\n                    visible: !SettingsController.isOnTv()', account)
        self.assertIn('modelData.icon !== "qrc:/images/controls/split-tunneling.svg"', account)
        self.assertIn('id: splitTunnelingDrawer\n        // The TV UI must never expose', account)
        self.assertIn('id: splitTunnelingButton\n                // Android TV:', settings)
        self.assertIn('visible: !SettingsController.isOnTv()', settings)
        self.assertIn('SettingsController.isOnTv() && page === PageEnum.PageSettingsSplitTunneling', start)

    def test_android_15_cutouts_and_deprecated_bar_setters_are_guarded(self):
        for theme in ("values/styles.xml", "values-v31/styles.xml"):
            content = (ANDROID / "res" / theme).read_text()
            self.assertIn('<item name="android:windowLayoutInDisplayCutoutMode">always</item>', content)
            self.assertNotIn('>shortEdges<', content)
        activity = (ANDROID / "src/org/amnezia/vpn/AmneziaActivity.kt").read_text()
        # QtActivity is not a ComponentActivity; use AndroidX Core's
        # Window-based modern equivalent on all Android 14+ devices.
        self.assertIn("WindowCompat.enableEdgeToEdge(window)", activity)
        self.assertNotIn("WindowCompat.setDecorFitsSystemWindows(window, false)", activity)
        self.assertNotIn("window.navigationBarColor =", activity)
        self.assertNotIn("statusBarColor =", activity)
        self.assertIn("WindowInsetsCompat.Type.systemBars()", activity)


if __name__ == "__main__":
    unittest.main()
