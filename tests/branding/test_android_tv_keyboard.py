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
    def test_leanback_banner_reuses_the_real_application_icon(self):
        manifest = ET.parse(ANDROID / "AndroidManifest.xml").getroot()
        application = manifest.find("application")
        self.assertEqual(application.get(NS + "banner"), "@drawable/tunnelcore_tv_banner")
        self.assertEqual(application.get(NS + "icon"), "@mipmap/icon")
        banner_file = ANDROID / "res" / "drawable" / "tunnelcore_tv_banner.xml"
        banner = ET.parse(banner_file).getroot()
        self.assertEqual(banner.tag, "layer-list")
        items = banner.findall("item")
        self.assertEqual(len(items), 2)
        self.assertEqual(items[0].get(NS + "drawable"),
                         "@drawable/tunnelcore_tv_banner_background")
        self.assertEqual(items[1].get(NS + "drawable"), "@mipmap/icon")
        self.assertEqual(items[1].get(NS + "width"), "108dp")
        self.assertEqual(items[1].get(NS + "height"), "108dp")
        self.assertNotIn("android:pathData", banner_file.read_text(encoding="utf-8"))

        # The banner uses exactly the same resource as the launcher icon:
        # no re-created shield / T vectors and no copied Amnezia artwork.
        self.assertTrue((ANDROID / "res" / "mipmap-anydpi-v26" / "icon.xml").exists())
        background = ET.parse(ANDROID / "res" / "drawable"
                              / "tunnelcore_tv_banner_background.xml").getroot()
        self.assertEqual(background.tag, "vector")
        self.assertEqual(background.get(NS + "width"), "320dp")
        self.assertEqual(background.get(NS + "height"), "180dp")
        self.assertNotIn("amneziavpn", banner_file.read_text(encoding="utf-8").lower())

    def test_android_tv_keyboard_visible_even_without_ime_insets(self):
        source = ACCOUNT.read_text(encoding="utf-8")
        self.assertIn("Qt.inputMethod.visible || PageController.imeHeight > 0", source)
        self.assertIn("function onKeyboardRectangleChanged()", source)
        self.assertIn("function onImeHeightChanged()", source)
        self.assertIn("onHeightChanged: root.scheduleInputVisibility()", source)
        self.assertIn("onContentHeightChanged: root.scheduleInputVisibility()", source)

    def test_numeric_code_explicitly_requests_android_keyboard(self):
        source = ACCOUNT.read_text(encoding="utf-8")
        login_field = source.split("id: loginField", 1)[1].split(
            "id: passwordField", 1
        )[0]
        self.assertIn("requestAndroidIme: !root.emailMode", login_field)
        self.assertIn("Qt.ImhDigitsOnly", login_field)
        widget = (ROOT / "client" / "ui" / "qml" / "Controls2"
                  / "TextFieldWithHeaderType.qml").read_text(encoding="utf-8")
        self.assertIn("function showRequestedAndroidKeyboard()", widget)
        self.assertIn("id: androidImeRetry", widget)
        self.assertIn("interval: 220", widget)
        self.assertIn("androidImeRetry.restart()", widget)
        self.assertIn("SystemController.requestSoftKeyboard()", widget)

        kotlin = (ANDROID / "src" / "org" / "amnezia" / "vpn"
                  / "AmneziaActivity.kt").read_text(encoding="utf-8")
        self.assertIn("val focusedView = window.decorView.findFocus()", kotlin)
        self.assertIn("?: findQtInputView(window.decorView)", kotlin)
        self.assertIn("Configuration.KEYBOARD_NOKEYS", kotlin)
        self.assertIn("InputMethodManager.SHOW_FORCED", kotlin)
        self.assertIn(
            "!qtInputView.hasFocus() && !qtInputView.requestFocus()", kotlin
        )
        self.assertIn('view::class.simpleName == "QtEditText"', kotlin)
        self.assertNotIn("showSoftInput(qtView", kotlin)

        telegram_field = source.split("id: telegramCodeField", 1)[1].split(
            "BasicButtonType {", 1
        )[0]
        self.assertIn("requestAndroidIme: true", telegram_field)

    def test_accessory_strip_is_reopened_as_full_keyboard(self):
        kotlin = (ANDROID / "src" / "org" / "amnezia" / "vpn"
                  / "AmneziaActivity.kt").read_text(encoding="utf-8")
        self.assertIn("accessoryStripOnly", kotlin)
        self.assertIn("hideSoftInputFromWindow", kotlin)
        self.assertIn("inputMethod.restartInput(qtInputView)", kotlin)
        self.assertIn("WindowInsetsCompat.Type.ime()", kotlin)
        self.assertIn("InputMethodManager.SHOW_FORCED", kotlin)

    def test_cancel_returns_to_auth_method_selection(self):
        source = ACCOUNT.read_text(encoding="utf-8")
        self.assertIn('objectName: "authCancelButton"', source)
        self.assertIn('text: qsTr("Cancel")', source)
        self.assertIn("clickedFunc: root.cancelAuthentication", source)
        cancel = source.split("function cancelAuthentication()", 1)[1].split(
            "function submit()", 1
        )[0]
        for requirement in (
            "root.forceActiveFocus()",
            "Qt.inputMethod.hide()",
            "root.showWelcome = true",
            "root.registrationMode = false",
            "root.emailMode = true",
            'loginField.textField.text = ""',
            'passwordField.textField.text = ""',
            'confirmPasswordField.textField.text = ""',
            "scroll.contentY = 0",
            "TunnelCoreController.clearError()",
        ):
            with self.subTest(requirement=requirement):
                self.assertIn(requirement, cancel)

        form = source.split('id: authCard', 1)[1].split(
            'objectName: "accountDeletionWebsiteGuest"', 1
        )[0]
        self.assertLess(form.index('id: authSubmitButton'),
                        form.index('objectName: "authCancelButton"'))
        self.assertIn('root.registrationMode ? qsTr("Create account") : qsTr("Sign in")', form)

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
