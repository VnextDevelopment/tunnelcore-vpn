"""Guard against upstream Amnezia assets leaking into TunnelCore installers."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def source(relative_path):
    return (ROOT / relative_path).read_text(encoding="utf-8")


class BrandingSafetyTests(unittest.TestCase):
    def test_unique_desktop_service_and_installers(self):
        common = source("client/cmake/branding/common.cmake")
        cpack = source("cmake/CPack.cmake")
        server = source("service/server/CMakeLists.txt")
        self.assertIn('set(CLIENT_SERVICE_NAME "TunnelCoreVPN-service"', common)
        self.assertIn("set(PROJECT TunnelCoreVPN-service)", server)
        self.assertNotIn("set(PROJECT AmneziaVPN-service)", server)
        self.assertIn('set(CPACK_PACKAGE_INSTALL_DIRECTORY "TunnelCoreVPN")', cpack)
        self.assertNotIn("CPACK_PREFLIGHT_AMNEZIAVPN_SCRIPT", cpack)
        self.assertIn("com.vnextdev.tunnelcorevpn.pkg", cpack)
        self.assertIn("TunnelCoreVPN_${AMNEZIAVPN_VERSION}_macos_x64", cpack)
        self.assertIn("TunnelCoreVPN_${AMNEZIAVPN_VERSION}_linux_x64", cpack)

    def test_macos_install_and_firewall_are_independent(self):
        install = source("deploy/data/macos/post_install.sh")
        uninstall = source("deploy/data/macos/post_uninstall.sh")
        plist = source("deploy/data/macos/AmneziaVPN.plist")
        firewall = source("client/platforms/macos/daemon/macosfirewall.cpp")
        for script in (install, uninstall):
            self.assertIn("APP_NAME=TunnelCoreVPN", script)
            self.assertNotIn("APP_NAME=AmneziaVPN", script)
            self.assertNotIn("killall -9", script)
        self.assertIn("TunnelCoreVPN-service", plist)
        self.assertIn("/Applications/TunnelCoreVPN.app", plist)
        self.assertIn('BRAND_IDENTIFIER "tcore"', firewall)
        self.assertIn("/Library/Application Support/TunnelCoreVPN/pf", firewall)
        self.assertNotIn("pfctl -F all -f /etc/pf.conf", firewall)
        self.assertNotIn('if grep -Fq', firewall)

    def test_linux_does_not_manage_upstream_processes(self):
        install = source("deploy/data/linux/post_install.sh")
        uninstall = source("deploy/data/linux/post_uninstall.sh")
        self.assertIn("APP_NAME=TunnelCoreVPN", install)
        self.assertIn("APP_NAME=TunnelCoreVPN", uninstall)
        self.assertNotIn("killall", install + uninstall)
        self.assertIn("TunnelCoreVPN-service", source("deploy/data/linux/AmneziaVPN.service"))
        self.assertIn("Exec=/opt/TunnelCoreVPN/bin/TunnelCoreVPN", source("deploy/data/linux/AmneziaVPN.desktop"))

    def test_apple_identifiers_are_ours(self):
        apple = source("client/cmake/branding/apple.cmake")
        self.assertIn("com.vnextdev.tunnelcorevpn", apple)
        self.assertIn("group.com.vnextdev.tunnelcorevpn", apple)
        self.assertNotIn("X7UJ388FXK", apple)
        self.assertNotIn("org.amnezia.AmneziaVPN", apple)
        for path in (
            "client/ios/app/main.entitlements",
            "client/ios/networkextension/AmneziaVPNNetworkExtension.entitlements",
            "client/macos/app/app.entitlements",
            "client/macos/networkextension/AmneziaVPNNetworkExtension.entitlements",
        ):
            self.assertIn("group.com.vnextdev.tunnelcorevpn", source(path))
            self.assertNotIn("group.org.amnezia.AmneziaVPN", source(path))

    def test_updates_do_not_link_to_upstream_store(self):
        updater = source("client/core/controllers/updateController.cpp")
        self.assertNotIn("id1600529900", updater)
        self.assertNotIn("AmneziaVPN_%1", updater)
        self.assertIn("TunnelCoreVPN_%1", updater)


if __name__ == "__main__":
    unittest.main()
