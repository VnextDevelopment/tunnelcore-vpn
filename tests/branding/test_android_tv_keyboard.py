"""Regression guards for Android TV launcher branding and IME-aware auth forms.

Static checks only: physical Android TV / phone tests still required.
"""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
ANDROID = ROOT / "client" / "android"
ACCOUNT = ROOT / "client" / "ui" / "qml" / "Pages2" / "PageTunnelCoreAccount.qml"
NS = "{http://schemas.android.com/apk/res/android}"


class AndroidTvKeyboardTest(unittest.TestCase):
    def test_leanback_banner_is_tunnelcore_vector(self):
        manifest = ET.parse(ANDROID / "AndroidManifest.xml").getroot()
        application = manifest.find("application")
        self.assertEqual(application.get(NS + "banner"), "@drawable/tunnelcore_tv_banner")
        banner_file = ANDROID / "res" / "drawable" / "tunnelcore_tv_banner.xml"
        self.assertTrue(banner_file.exists())
        banner = ET.parse(banner_file).getroot()
        self.assertEqual(banner.tag, "vector")
        self.assertEqual(banner.get(NS + "width"), "320dp")
        self.assertEqual(banner.get(NS + "height"), "180dp")
        self.assertGreaterEqual(len(banner.findall(".//path")), 10)
        self.assertNotIn("amneziavpn", banner_file.read_text(encoding="utf-8").lower())

    def test_android_tv_keyboard_visible_even_without_ime_insets(self):
        source = ACCOUNT.read_text(encoding="utf-8")
        self.assertIn("Qt.inputMethod.visible || PageController.imeHeight > 0", source)
        self.assertIn("function onKeyboardRectangleChanged()", source)
        self.assertIn("function onImeHeightChanged()", source)
        self.assertIn("onHeightChanged: root.scheduleInputVisibility()", source)
        self.assertIn("onContentHeightChanged: root.scheduleInputVisibility()", source)

    def test_compact_login_keeps_next_input_reachable(self):
        source = ACCOUNT.read_text(encoding="utf-8")
        self.assertIn("readonly property bool compactAuthLayout:", source)
        self.assertIn("visible: !TunnelCoreController.authenticated && !root.compactAuthLayout", source)
        self.assertIn("visible: root.emailMode && !root.compactAuthLayout", source)
        self.assertIn("candidate.mapToItem(content, 0, 0)", source)
        self.assertIn("[passwordField, authSubmitButton]", source)
        self.assertIn("[confirmPasswordField, passwordField]", source)
        self.assertIn("id: authSubmitButton", source)
        self.assertIn("confirmPasswordField.textField.forceActiveFocus()", source)


if __name__ == "__main__":
    unittest.main()
