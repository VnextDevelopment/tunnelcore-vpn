"""Keep the in-app TunnelCore privacy link visible and production-safe."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class PrivacyPolicyLinkTests(unittest.TestCase):
    def test_account_page_links_to_tunnelcore_policy(self):
        account_page = (
            ROOT / "client/ui/qml/Pages2/PageTunnelCoreAccount.qml"
        ).read_text()

        self.assertIn('objectName: "tunnelCorePrivacyPolicyLink"', account_page)
        self.assertIn("https://vnextdev.com/tunnelcore/privacy", account_page)
        self.assertIn(
            "https://vnextdev.com/tunnelcore/privacy#account-deletion",
            account_page,
        )
        self.assertIn("Qt.openUrlExternally(link)", account_page)


if __name__ == "__main__":
    unittest.main()
