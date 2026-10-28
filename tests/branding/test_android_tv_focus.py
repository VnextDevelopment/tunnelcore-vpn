"""Static regression checks for high-contrast Android TV D-pad focus indicators."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONTROLS = ROOT / "client/ui/qml/Controls2"
ACCOUNT = (ROOT / "client/ui/qml/Pages2/PageTunnelCoreAccount.qml").read_text()
CONNECT = (ROOT / "client/ui/qml/Components/ConnectButton.qml").read_text()
QUESTION = (ROOT / "client/ui/qml/Components/QuestionDrawer.qml").read_text()
MAIN = (ROOT / "client/ui/qml/main2.qml").read_text()
SPLIT = (ROOT / "client/ui/qml/Pages2/PageSettingsSplitTunneling.qml").read_text()
HOME_SPLIT = (ROOT / "client/ui/qml/Components/HomeSplitTunnelingDrawer.qml").read_text()


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

    def test_home_split_sheet_is_remotely_focusable_not_only_settings_page(self):
        # This is the modal visible in the TV screenshot above the five tabs.
        self.assertIn('readonly property bool remoteNavigationScope:', HOME_SPLIT)
        self.assertIn('function navigateRemote(forward)', HOME_SPLIT)
        self.assertIn('function focusableRows()', HOME_SPLIT)
        self.assertIn('rows[0].rightButton.forceActiveFocus(Qt.TabFocusReason)', HOME_SPLIT)
        self.assertIn('rows[next].rightButton.forceActiveFocus(Qt.TabFocusReason)', HOME_SPLIT)
        self.assertIn('rightButton.focusPolicy: Qt.StrongFocus', HOME_SPLIT)
        self.assertNotIn('rightButton.focusPolicy: SettingsController.isOnTv() ? Qt.NoFocus', HOME_SPLIT)
        self.assertIn('if (root.navigatingToSettings) return', HOME_SPLIT)
        self.assertIn('objectName: "homeSplitSitesRow"', HOME_SPLIT)
        self.assertIn('objectName: "homeSplitServerRow"', HOME_SPLIT)
        self.assertIn('Keys.onBackPressed:', HOME_SPLIT)
        self.assertIn('FocusController.setFocusItem(previous)', HOME_SPLIT)
        self.assertIn('clickedFunction: root.goToSplitSettings', HOME_SPLIT)

    def test_tv_split_tunneling_has_scrollable_header_and_focus_order(self):
        self.assertIn('objectName: "splitTunnelingHeaderViewport"', SPLIT)
        self.assertIn('contentHeight: header.y + header.implicitHeight', SPLIT)
        self.assertIn('interactive: root.tvMode && !root.tvModalOpen', SPLIT)
        self.assertIn('anchors.top: tvHeaderViewport.bottom', SPLIT)
        self.assertIn('readonly property bool remoteNavigationScope: tvMode', SPLIT)
        self.assertIn('function navigateRemote(forward)', SPLIT)
        self.assertIn('root.scrollHeaderTo(target)', SPLIT)
        self.assertIn('function focusSite(index)', SPLIT)
        self.assertIn('property alias remoteSiteAction: site.rightButton', SPLIT)

    def test_tv_split_tunneling_country_picker_has_dpad_selection(self):
        self.assertIn('function tvFocusCountryList()', SPLIT)
        self.assertIn('view.forceActiveFocus(Qt.TabFocusReason)', SPLIT)
        self.assertIn('view.positionViewAtIndex(selected, ListView.Contain)', SPLIT)
        self.assertIn('Keys.onSelectPressed: if (currentItem) currentItem.clicked()', SPLIT)
        self.assertIn('countryRow.ListView.isCurrentItem', SPLIT)
        self.assertIn('function tvFocusModeList()', SPLIT)
        self.assertIn('function tvMoveMode(forward)', SPLIT)

    def test_tv_split_picker_is_real_modal_with_no_background_scrolling(self):
        PAGE_START = (ROOT / "client/ui/qml/Pages2/PageStart.qml").read_text()
        DROP = (CONTROLS / "DropDownType.qml").read_text()
        RADIO = (CONTROLS / "ListViewWithRadioButtonType.qml").read_text()
        self.assertIn('readonly property bool tvModalOpen:', SPLIT)
        self.assertIn('function handleTvModalKey(key)', SPLIT)
        self.assertIn('enabled: !root.tvModalOpen', SPLIT)
        self.assertIn('enabled: root.pageEnabled && !root.tvModalOpen', SPLIT)
        self.assertIn('readonly property bool tvChildModalOpen:', PAGE_START)
        self.assertIn('if (root.tvChildModalOpen)', PAGE_START)
        self.assertIn('visible: TunnelCoreController.authenticated && !root.tvChildModalOpen', PAGE_START)
        self.assertIn('signal popupOpened', DROP)
        self.assertIn('signal popupClosed', DROP)
        self.assertIn('Keys.onSelectPressed:', DROP)
        self.assertIn('onPopupOpened:', SPLIT)
        self.assertIn('onPopupClosed:', SPLIT)
        self.assertIn('Component.onCompleted: root.tvCountryList = geoCountriesList', SPLIT)
        self.assertIn('Component.onCompleted: root.tvCountrySearch = countrySearchInput', SPLIT)
        self.assertIn('Component.onCompleted: root.tvModeList = modeOptionsList', SPLIT)
        self.assertIn('tvNavigationHandler: root.tvMode ? root.tvMoveMode : null', SPLIT)
        self.assertIn('property var tvNavigationHandler:', RADIO)

    def test_tv_split_layout_collapses_empty_sites_list_and_footer(self):
        self.assertIn('visible: !root.tvMode || count > 0', SPLIT)
        self.assertIn('id: footerBar', SPLIT)
        self.assertIn('anchors.top: root.tvMode ? (listView.count > 0', SPLIT)
        self.assertIn('height: root.tvMode', SPLIT)
        self.assertIn('drawerHeight: root.tvMode ? 0.98', SPLIT)

    def test_basic_button_does_not_dispatch_center_twice(self):
        # The Qt Button already handles DPAD_CENTER. A second attached
        # Keys.onSelectPressed handler causes duplicate submissions.
        self.assertNotIn("Keys.onSelectPressed:", (CONTROLS / "BasicButtonType.qml").read_text())


if __name__ == "__main__":
    unittest.main()
