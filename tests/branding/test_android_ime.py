"""Guard Qt 6.10's Android IME integration against a decorView listener override."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ANDROID_ACTIVITY = ROOT / "client/android/src/org/amnezia/vpn/AmneziaActivity.kt"
SPLIT_TUNNELING = ROOT / "client/ui/qml/Pages2/PageSettingsSplitTunneling.qml"


class AndroidImeIntegrationTests(unittest.TestCase):
    def test_qt_window_owns_insets_listener(self):
        kotlin = ANDROID_ACTIVITY.read_text()
        self.assertNotIn("setOnApplyWindowInsetsListener(", kotlin)
        self.assertIn("ViewTreeObserver.OnGlobalLayoutListener", kotlin)
        self.assertIn("ViewCompat.getRootWindowInsets(decor)", kotlin)
        self.assertIn("qtInitialized.await()", kotlin)
        self.assertIn("removeOnGlobalLayoutListener(listener)", kotlin)

    def test_android_keyboard_works_for_both_split_tunnel_fields(self):
        view = SPLIT_TUNNELING.read_text()
        self.assertIn('objectName: "splitTunnelingCountrySearchInput"', view)
        self.assertIn('requestAndroidIme: true', view)
        self.assertIn("SystemController.requestSoftKeyboard()", view)

        # The emulator reports a hardware keyboard. The native fallback must
        # target the focused QtEditText and force the full keyboard; targeting
        # QtWindow produces only Gboard's accessory strip.
        kotlin = ANDROID_ACTIVITY.read_text()
        self.assertIn("val focusedView = window.decorView.findFocus()", kotlin)
        self.assertIn('it::class.simpleName == "QtEditText"', kotlin)
        self.assertIn("Configuration.KEYBOARD_NOKEYS", kotlin)
        self.assertIn("InputMethodManager.SHOW_FORCED", kotlin)
        self.assertNotIn("showSoftInput(qtView", kotlin)


if __name__ == "__main__":
    unittest.main()
