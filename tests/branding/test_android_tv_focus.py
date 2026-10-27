"""Static regression checks for high-contrast Android TV D-pad focus indicators."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONTROLS = ROOT / "client/ui/qml/Controls2"
ACCOUNT = (ROOT / "client/ui/qml/Pages2/PageTunnelCoreAccount.qml").read_text()
CONNECT = (ROOT / "client/ui/qml/Components/ConnectButton.qml").read_text()


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

    def test_tv_center_button_activates_regular_buttons(self):
        self.assertIn("Keys.onSelectPressed:", (CONTROLS / "BasicButtonType.qml").read_text())


if __name__ == "__main__":
    unittest.main()
