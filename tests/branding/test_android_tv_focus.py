"""Static regression checks for high-contrast Android TV D-pad focus indicators."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONTROLS = ROOT / "client/ui/qml/Controls2"
ACCOUNT = (ROOT / "client/ui/qml/Pages2/PageTunnelCoreAccount.qml").read_text()
CONNECT = (ROOT / "client/ui/qml/Components/ConnectButton.qml").read_text()
QUESTION = (ROOT / "client/ui/qml/Components/QuestionDrawer.qml").read_text()
MAIN = (ROOT / "client/ui/qml/main2.qml").read_text()


class AndroidTvFocusTest(unittest.TestCase):
    def test_shared_controls_have_tv_blue_focus_ring(self):
        for filename in ("BasicButtonType.qml", "ImageButtonType.qml",
                         "LabelWithButtonType.qml", "DropDownType.qml",
                         "SwitcherType.qml", "TabImageButtonType.qml",
                         "TextFieldWithHeaderType.qml"):
            with self.subTest(filename=filename):
                source = (CONTROLS / filename).read_text()
                self.assertIn("SettingsController.isOnTv() ? AmneziaStyle.color.tcBlue", source)
                self.assertIn("SettingsController.isOnTv() ? 3 : 1", source)

    def test_auth_focus_moves_to_visible_control(self):
        self.assertIn("function focusAuthenticationEntry()", ACCOUNT)
        self.assertIn("Qt.callLater(root.focusAuthenticationEntry)", ACCOUNT)
        self.assertIn("target.forceActiveFocus(Qt.TabFocusReason)", ACCOUNT)
        self.assertIn("borderFocusedWidth: SettingsController.isOnTv() ? 3 : 2", ACCOUNT)

    def test_vpn_circle_and_subscription_card_have_full_size_tv_ring(self):
        self.assertIn('objectName: "tvConnectFocusRing"', CONNECT)
        self.assertIn("root.tunnelCoreMode && root.activeFocus && root.enabled", CONNECT)
        self.assertIn("isFocusable: SettingsController.isOnTv()", ACCOUNT)
        self.assertIn("Keys.onSelectPressed: subscriptionsDrawer.openTriggered()", ACCOUNT)
        self.assertIn("rightButton.focusPolicy: SettingsController.isOnTv() ? Qt.NoFocus", ACCOUNT)

    def test_confirmations_trap_remote_navigation_in_modal(self):
        self.assertIn("function moveConfirmationFocus(forward)", QUESTION)
        self.assertIn("navigationHandler: SettingsController.isOnTv() ? root.moveConfirmationFocus", QUESTION)
        self.assertIn('Component.onCompleted: root.noButtonItem = noButton', QUESTION)
        self.assertIn('Component.onCompleted: root.yesButtonItem = yesButton', QUESTION)
        self.assertIn("initial.forceActiveFocus(Qt.TabFocusReason)", QUESTION)
        self.assertIn("Keys.onBackPressed:", QUESTION)
        self.assertIn("Keys.onEscapePressed:", QUESTION)
        self.assertIn("FocusController.setFocusItem(previous)", QUESTION)
        self.assertIn("enabled: !(SettingsController.isOnTv() && questionDrawer.isOpened)", MAIN)

    def test_basic_button_does_not_dispatch_center_twice(self):
        # The Qt Button already handles DPAD_CENTER. A second attached
        # Keys.onSelectPressed handler causes duplicate submissions.
        self.assertNotIn("Keys.onSelectPressed:", (CONTROLS / "BasicButtonType.qml").read_text())


if __name__ == "__main__":
    unittest.main()
