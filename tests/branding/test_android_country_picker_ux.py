"""Contrast and input regression guards for Android split-tunneling country picker.

These checks complement, but do not replace, touch + IME tests on devices.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONTROLS = ROOT / "client" / "ui" / "qml" / "Controls2"
PAGES = ROOT / "client" / "ui" / "qml" / "Pages2"


class CountryPickerUxTest(unittest.TestCase):
    def test_shared_dropdown_defaults_stay_compatible(self):
        source = (CONTROLS / "DropDownType.qml").read_text(encoding="utf-8")
        self.assertIn("property color drawerBackgroundColor: AmneziaStyle.color.onyxBlack", source)
        self.assertIn("property color drawerHeaderColor: AmneziaStyle.color.paleGray", source)
        self.assertIn("defaultColor: root.drawerBackgroundColor", source)
        self.assertIn("headerColor: root.drawerHeaderColor", source)
        self.assertIn("imageColor: root.drawerBackButtonColor", source)

    def test_country_picker_matches_tunnelcore_light_palette(self):
        source = (PAGES / "PageSettingsSplitTunneling.qml").read_text(encoding="utf-8")
        picker = source.split("id: countryBypassSelector", 1)[1].split(
            "id: selector", 1
        )[0]
        for expected in (
            "drawerBackgroundColor: AmneziaStyle.color.tcCard",
            "drawerHeaderColor: AmneziaStyle.color.tcInk",
            "drawerBorderColor: AmneziaStyle.color.tcStroke",
            "textColor: AmneziaStyle.color.tcInk",
            "itemColor: AmneziaStyle.color.tcCard",
            "itemSelectedColor: AmneziaStyle.color.tcSurfaceBlue",
            "placeholderTextColor: AmneziaStyle.color.tcMuted",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, picker)

    def test_country_search_whole_field_is_tappable(self):
        source = (PAGES / "PageSettingsSplitTunneling.qml").read_text(encoding="utf-8")
        search_box = source.split("id: countrySearchBox", 1)[1].split(
            "RowLayout {", 1
        )[0]
        self.assertIn("TapHandler {", search_box)
        self.assertIn("onTapped: countrySearchInput.showKeyboard()", search_box)
        self.assertIn("function showKeyboard()", source)
        self.assertIn("forceActiveFocus(Qt.MouseFocusReason)", source)
        self.assertIn("function requestAndroidKeyboard()", source)
        self.assertNotIn("countryImeRetry", source)
        self.assertIn("property bool androidImeRequestPending: false", source)
        self.assertIn("function scheduleAndroidKeyboard()", source)
        self.assertIn("Qt.callLater(function() {", source)
        self.assertIn("scheduleAndroidKeyboard()", source)
        self.assertIn("SystemController.requestSoftKeyboard()", source)
        self.assertIn("Qt.inputMethod.visible || PageController.imeHeight > 0", source)

    def test_reparented_drawer_is_above_page_inputs(self):
        source = (CONTROLS / "DropDownType.qml").read_text(encoding="utf-8")
        drawer = source.split("id: menu", 1)[1]
        self.assertIn("parent: drawerParent", drawer)
        self.assertIn("z: isClosed ? 0 : 100 + depthIndex", drawer)


if __name__ == "__main__":
    unittest.main()
