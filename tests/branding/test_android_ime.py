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

    def test_email_sign_in_keeps_password_accessible_with_keyboard(self):
        view = (ROOT / "client/ui/qml/Pages2/PageTunnelCoreAccount.qml").read_text()
        self.assertIn("readonly property bool keyboardVisible:", view)
        self.assertIn("onImeHeightChanged()", view)
        self.assertIn("onContentHeightChanged: Qt.callLater(root.keepFocusedInputVisible)", view)
        self.assertIn(": [authSubmitButton, passwordField]", view)
        self.assertIn("nextBottom - fieldTop + margin * 2 <= scroll.height", view)
        self.assertIn("visible: !TunnelCoreController.authenticated && !root.keyboardVisible", view)

    def test_email_registration_scrolls_to_confirmation_and_next_field(self):
        view = (ROOT / "client/ui/qml/Pages2/PageTunnelCoreAccount.qml").read_text()
        self.assertIn("? [confirmPasswordField, passwordField]", view)
        self.assertIn("? [authSubmitButton, confirmPasswordField]", view)
        self.assertIn("confirmPasswordField.textField.forceActiveFocus()", view)
        self.assertIn("id: authSubmitButton", view)


if __name__ == "__main__":
    unittest.main()
