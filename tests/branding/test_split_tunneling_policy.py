"""The TunnelCore VPN feature set and Android Play permissions stay consistent."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def source(path):
    return (ROOT / path).read_text(encoding="utf-8")


class UniformSplitTunnelingTests(unittest.TestCase):
    def test_android_does_not_request_broad_package_visibility(self):
        manifest = source("client/android/AndroidManifest.xml")
        self.assertNotIn("android.permission.QUERY_ALL_PACKAGES", manifest)

    def test_app_based_routing_is_not_advertised_on_any_platform(self):
        for page in (
            "client/ui/qml/Pages2/PageSettingsConnection.qml",
            "client/ui/qml/Components/HomeSplitTunnelingDrawer.qml",
        ):
            qml = source(page)
            self.assertNotIn("App-based split tunneling", qml)
            self.assertNotIn("PageSettingsAppSplitTunneling", qml)
            self.assertNotIn("isAppSplitTinnelingEnabled", qml)

        home = source("client/ui/qml/Pages2/PageHome.qml")
        self.assertNotIn("AppSplitTunnelingController.isSplitTunnelingEnabled", home)

    def test_legacy_app_rules_cannot_be_active_after_upgrade(self):
        repository = source("client/core/repositories/secureAppSettingsRepository.cpp")
        self.assertRegex(repository, re.compile(
            r"bool SecureAppSettingsRepository::isAppsSplitTunnelingEnabled\(\) const\s*"
            r"\{\s*return false;\s*\}"
        ))
        controller = source("client/core/controllers/appSplitTunnelingController.cpp")
        self.assertIn("m_appSettingsRepository->setAppsSplitTunnelingEnabled(false);", controller)

    def test_site_ip_and_geo_routing_still_available(self):
        drawer = source("client/ui/qml/Components/HomeSplitTunnelingDrawer.qml")
        page = source("client/ui/qml/Pages2/PageSettingsSplitTunneling.qml")
        self.assertIn("PageEnum.PageSettingsSplitTunneling", drawer)
        self.assertIn("IpSplitTunnelingController.toggleSplitTunneling", page)
        self.assertIn("TunnelCoreController.selectGeoRoutingCountry", page)


if __name__ == "__main__":
    unittest.main()
