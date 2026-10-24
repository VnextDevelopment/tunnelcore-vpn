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
IMAGES_QRC = (ROOT / "client" / "images" / "images.qrc").read_text(encoding="utf-8")

LIGHT_SETTINGS_PAGES = (
    "Pages2/PageSettingsConnection.qml",
    "Pages2/PageSettingsApplication.qml",
    "Pages2/PageSettingsBackup.qml",
    "Pages2/PageSettingsAbout.qml",
)

CHANGED_PAGES = (
    "Pages2/PageTunnelCoreAccount.qml",
    "Pages2/PageStart.qml",
    "Pages2/PageSettings.qml",
    *LIGHT_SETTINGS_PAGES,
    "Pages2/PageSettingsApiDevices.qml",
    "Pages2/PageSettingsApiAvailableCountries.qml",
    "Pages2/PageSettingsSplitTunneling.qml",
    "Pages2/PageSettingsAppSplitTunneling.qml",
    "Controls2/TabImageButtonType.qml",
    "Controls2/BackButtonType.qml",
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

    def test_welcome_card_does_not_duplicate_page_heading(self):
        welcome_card_header = ACCOUNT.split("id: welcomeContent", 1)[1].split(
            "id: welcomeFeatures", 1
        )[0]
        self.assertNotIn('qsTr("TunnelCore VPN")', welcome_card_header)
        self.assertNotIn('qsTr("Sign in to your account")', welcome_card_header)

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

    def test_logout_all_waits_for_vpn_disconnect(self):
        self.assertIn("property bool pendingLogoutAll: false", ACCOUNT)
        sign_out_flow = ACCOUNT.split("function signOutEverywhere()", 1)[1].split(
            "function localizedTariffName", 1
        )[0]
        self.assertLess(
            sign_out_flow.index("ConnectionController.closeConnection()"),
            sign_out_flow.index("TunnelCoreController.logoutAll()"),
        )
        self.assertIn("if (root.pendingLogoutAll", ACCOUNT)
        self.assertIn("root.signOutEverywhere()", ACCOUNT)

    def test_brand_tokens_defined(self):
        for token in set(re.findall(r"AmneziaStyle\.color\.(tc\w+)", ACCOUNT)):
            self.assertRegex(PALETTE, rf"property (?:color|string) {re.escape(token)}\b")

    def test_secondary_settings_pages_use_light_palette(self):
        for path in LIGHT_SETTINGS_PAGES:
            with self.subTest(path=path):
                source = (QML / path).read_text(encoding="utf-8")
                self.assertIn("color: AmneziaStyle.color.tcBackground", source)
                self.assertIn("imageColor: AmneziaStyle.color.tcInk", source)

    def test_split_tunneling_drawer_contrast(self):
        """Poco M6 Pro: avoid dark text on the old dark drawer background."""
        source = (QML / "Pages2" / "PageSettingsSplitTunneling.qml").read_text(
            encoding="utf-8"
        )
        actions = source.split("id: moreActionsDrawer", 1)[1].split(
            "id: importSitesDrawer", 1
        )[0]
        import_drawer = source.split("id: importSitesDrawer", 1)[1]
        for drawer in (actions, import_drawer):
            self.assertIn("defaultColor: AmneziaStyle.color.tcCard", drawer)
            self.assertIn("borderColor: AmneziaStyle.color.tcStroke", drawer)
            self.assertIn("headerColor: AmneziaStyle.color.tcInk", drawer)
            self.assertIn("textColor: AmneziaStyle.color.tcInk", drawer)
            self.assertIn("DividerType { color: AmneziaStyle.color.tcStroke }", drawer)
        self.assertIn("imageColor: AmneziaStyle.color.tcInk", import_drawer)
        self.assertRegex(
            source,
            r"color:\s*AmneziaStyle[.]color[.]tcMuted\s+maximumLineCount:\s*4",
        )

    def test_android_safe_brand_and_connection_icons(self):
        self.assertIn(
            '<file alias="icon.png">../android/res/mipmap-xxxhdpi/icon.png</file>',
            IMAGES_QRC,
        )
        connect_button = (QML / "Components" / "ConnectButton.qml").read_text(
            encoding="utf-8"
        )
        self.assertIn('source: "qrc:/images/controls/power.svg"', connect_button)
        self.assertIn("PaintedIcon {", connect_button)
        self.assertNotIn('text: "\\u23FB"', connect_button)
        for path in (
            "Pages2/PageTunnelCoreAccount.qml",
            "Pages2/PageSetupWizardStart.qml",
            "Pages2/PageSettingsAbout.qml",
        ):
            with self.subTest(path=path):
                source = (QML / path).read_text(encoding="utf-8")
                self.assertRegex(
                    source,
                    r'IconImageType\s*\{[^}]*source:\s*"qrc:/images/icon\.png"',
                )

    def test_ime_guard_and_password_visibility(self):
        self.assertIn("root.keepFocusedInputVisible", ACCOUNT)
        self.assertIn("PageController.safeAreaBottomMargin", ACCOUNT)
        self.assertIn("property bool passwordVisible: false", ACCOUNT)
        self.assertIn("TextInput.Normal : TextInput.Password", ACCOUNT)


if __name__ == "__main__":
    unittest.main()
