"""Guard Qt 6.10's Android IME integration against a decorView listener override."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AndroidImeIntegrationTests(unittest.TestCase):
    def test_qt_window_owns_insets_listener(self):
        kotlin = (ROOT / "client/android/src/org/amnezia/vpn/AmneziaActivity.kt").read_text()
        self.assertNotIn("setOnApplyWindowInsetsListener(", kotlin)
        self.assertIn("ViewTreeObserver.OnGlobalLayoutListener", kotlin)
        self.assertIn("ViewCompat.getRootWindowInsets(decor)", kotlin)
        self.assertIn("qtInitialized.await()", kotlin)
        self.assertIn("removeOnGlobalLayoutListener(listener)", kotlin)

    def test_android_keyboard_works_for_both_split_tunnel_fields(self):
        view = (ROOT / "client/ui/qml/Pages2/PageSettingsSplitTunneling.qml").read_text()
        self.assertIn('objectName: "splitTunnelingCountrySearchInput"', view)
        self.assertIn('requestAndroidIme: true', view)
        self.assertIn("SystemController.requestSoftKeyboard()", view)


if __name__ == "__main__":
    unittest.main()
