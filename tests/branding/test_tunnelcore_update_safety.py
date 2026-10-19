import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

class TunnelCoreUpdateSafety(unittest.TestCase):
    def test_no_upstream_update_gateway(self):
        source = (ROOT / "client/core/controllers/updateController.cpp").read_text()
        self.assertIn("https://vnextdev.com/api/tunnelcore/updates", source)
        self.assertNotIn("v1/app_update", source)
        self.assertNotIn("gw.amnezia.org", source)
        self.assertIn("QSaveFile", source)
        self.assertIn("QCryptographicHash::Sha256", source)
        self.assertIn("m_expectedSize", source)
        self.assertIn("tunnelCoreReleasePage", source)

    def test_no_upstream_release_upload_workflows(self):
        self.assertFalse((ROOT / ".github/workflows/tag-deploy.yml").exists())
        self.assertFalse((ROOT / ".github/workflows/tag-upload.yml").exists())
        self.assertFalse((ROOT / "deploy/deploy_s3.sh").exists())
        workflow = (ROOT / ".github/workflows/publish-release.yml").read_text()
        self.assertIn("Deploy workflow", workflow)
        self.assertIn("SHA256SUMS.txt", workflow)
        self.assertIn('[[ "$BRANCH" == "main"', workflow)

if __name__ == "__main__":
    unittest.main()
