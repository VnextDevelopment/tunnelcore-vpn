"""Regression checks for the TunnelCore QML redesign.

These static tests complement native Qt Android/Windows builds; they do not
pretend to test interactive QML or device-specific keyboard behavior.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
QML = ROOT / "client" / "ui" / "qml"

ACCOUNT = (QML / "Pages2" / "PageTunnelCoreAccount.qml").read_text(encoding="utf-8")
PAGE_START = (QML / "Pages2" / "PageStart.qml").read_text(encoding="utf-8")
PALETTE = (QML / "Modules" / "Style" / "AmneziaStyle.qml").read_text(encoding="utf-8")

CHANGED_PAGES = (
    "Pages2/PageTunnelCoreAccount.qml",
    "Pages2/PageStart.qml",
    "Pages2/PageSettings.qml",
    "Pages2/PageSettingsApiDevices.qml",
    "Pages2/PageSettingsApiAvailableCountries.qml",
    "Pages2/PageSettingsSplitTunneling.qml",
    "Pages2/PageSettingsAppSplitTunneling.qml",
    "Controls2/TabImageButtonType.qml",
    "Controls2/BaseHeaderType.qml",
    "Controls2/Header2Type.qml",
    "Components/ConnectButton.qml",
    "Components/HomeSplitTunnelingDrawer.qml",
    "Modules/Style/AmneziaStyle.qml",
)


def curly_balance(source: str) -> int:
    """Check QML nesting ignoring quoted strings and // /* */ comments."""
    depth = 0
    pos = 0
    mode = "code"
    while pos < len(source):
        ch = source[pos]
        nxt = source[pos + 1] if pos + 1 < len(source) else ""
        if mode == "line":
            if ch == "\n":
                mode = "code"
        elif mode == "block":
            if ch == "*" and nxt == "/":
                mode = "code"
                pos += 1
        elif mode in ("single", "double"):
            if ch == "\\":
                pos += 1
            elif ch == ("'" if mode == "single" else '"'):
                mode = "code"
        elif ch == "/" and nxt == "/":
            mode = "line"
            pos += 1
        elif ch == "/" and nxt == "*":
            mode = "block"
            pos += 1
        elif ch in ("'", '"'):
            mode = "single" if ch == "'" else "double"
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth < 0:
                raise AssertionError("Unexpected QML closing brace")
        pos += 1
    if mode not in ("code", "line"):
        raise AssertionError(f"Unterminated QML quote/comment: {mode}")
    return depth


class TunnelCoreUiTest(unittest.TestCase):
    def test_all_redesigned_qml_files_are_balanced(self):
        for path in CHANGED_PAGES:
            with self.subTest(path=path):
                self.assertEqual(curly_balance((QML / path).read_text(encoding="utf-8")), 0)

    def test_navigation_shows_actual_account_sections(self):
        for value in ('"home"', '"countries"', '"subscription"', '"profile"'):
            self.assertIn("root.viewMode === " + value, ACCOUNT)
        for name in ("homeTabButton", "countryTabButton", "subscriptionTabButton",
                     "profileTabButton", "settingsTabButton"):
            self.assertIn('id: ' + name, PAGE_START)
        self.assertIn('properties.viewMode = section || "home"', PAGE_START)

    def test_live_connection_and_country_not_a_screenshot(self):
        self.assertIn("tunnelCoreMode: true", ACCOUNT)
        self.assertIn("clickedFunc: root.connectSelectedLocation", ACCOUNT)
        self.assertIn("ConnectionController.connectionStateText", ACCOUNT)
        self.assertIn("TunnelCoreController.vpnCountries", ACCOUNT)
        self.assertIn("TunnelCoreController.selectVpnCountry(countryCode)", ACCOUNT)
        self.assertIn("TunnelCoreController.primarySubscription", ACCOUNT)

    def test_real_billing_and_account_actions(self):
        for real_method in ("TunnelCoreController.renewSubscription()",
                            "TunnelCoreController.logoutAll()",
                            "TunnelCoreController.requestAccountDeletion()",
                            "TunnelCoreController.loginEmail(",
                            "TunnelCoreController.loginCode(",
                            "TunnelCoreController.registerEmail("):
            self.assertIn(real_method, ACCOUNT)
        self.assertIn("TunnelCoreController.usesAppleBilling", ACCOUNT)
        self.assertIn("TunnelCoreController.externalRenewalLinkAllowed", ACCOUNT)
        self.assertNotIn("1 999 ₽", ACCOUNT)
        self.assertNotIn("Осталось 7 дней", ACCOUNT)
        self.assertNotIn("5 devices", ACCOUNT)

    def test_brand_tokens_defined(self):
        for token in set(re.findall(r"AmneziaStyle\\.color\\.(tc\\w+)", ACCOUNT)):
            self.assertRegex(PALETTE, rf"property (?:color|string) {re.escape(token)}\\b")

    def test_ime_guard_and_password_visibility(self):
        self.assertIn("root.keepFocusedInputVisible", ACCOUNT)
        self.assertIn("PageController.safeAreaBottomMargin", ACCOUNT)
        self.assertIn("property bool passwordVisible: false", ACCOUNT)
        self.assertIn("TextInput.Normal : TextInput.Password", ACCOUNT)


if __name__ == "__main__":
    unittest.main()
