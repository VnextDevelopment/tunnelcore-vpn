"""Regression checks for the manually dispatched signed sideload APK workflow.

These ensure a GitHub Release is optional and that signed Android artifacts
remain usable without publishing to GitHub Releases or Google Play.
"""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = (ROOT / ".github/workflows/publish-android-apk.yml").read_text()
BUILDER = (ROOT / "deploy/build.sh").read_text()


class AndroidSideloadReleaseWorkflowTest(unittest.TestCase):
    def test_version_is_optional_and_source_defaults_to_main(self):
        self.assertIn("name: Build signed universal Android APK", WORKFLOW)
        self.assertIn("ref: ${{ inputs.publish_release && format('v{0}', inputs.version) || 'main' }}", WORKFLOW)
        self.assertIn("REQUESTED_VERSION: ${{ inputs.version }}", WORKFLOW)
        self.assertIn('echo "ANDROID_BUILD_NUMBER=$build_number" >> "$GITHUB_ENV"', WORKFLOW)
        self.assertIn('if [[ "$PUBLISH_RELEASE" == "true" ]]; then', WORKFLOW)
        self.assertNotIn("Checkout pinned release tag", WORKFLOW)
        self.assertNotIn("Verify release and version", WORKFLOW)

    def test_release_is_not_a_prerequisite_for_default_build(self):
        self.assertIn("if: ${{ inputs.publish_release }}", WORKFLOW)
        self.assertIn("Verify optional published GitHub Release", WORKFLOW)
        self.assertIn("Optionally attach APK to matching GitHub Release", WORKFLOW)
        self.assertLess(WORKFLOW.index("Build signed OSS APK"),
                        WORKFLOW.index("Upload signed Universal APK to Actions Artifacts"))
        self.assertLess(WORKFLOW.index("Upload signed Universal APK to Actions Artifacts"),
                        WORKFLOW.index("Optionally attach APK to matching GitHub Release"))
        self.assertNotIn("gh release create", WORKFLOW)

    def test_android_version_and_signature_are_consistent(self):
        self.assertIn('GITHUB_RUN_NUMBER="$ANDROID_BUILD_NUMBER" deploy/build.sh', WORKFLOW)
        self.assertIn("AMNEZIAVPN_VERSION=$REQUESTED_VERSION", WORKFLOW)
        self.assertIn('args+=("-DAMNEZIAVPN_VERSION=$AMNEZIAVPN_VERSION")', BUILDER)
        self.assertIn("CMAKE_PROJECT_VERSION:STATIC=", WORKFLOW)
        self.assertIn("apksigner", WORKFLOW)
        self.assertIn("--sign", WORKFLOW)
        for abi in ("armeabi-v7a", "arm64-v8a", "x86", "x86_64"):
            self.assertIn(abi, WORKFLOW)

    def test_apk_and_checksum_are_uploaded_without_release(self):
        self.assertIn("uses: actions/upload-artifact@v7", WORKFLOW)
        self.assertIn("if-no-files-found: error", WORKFLOW)
        self.assertIn("retention-days: 30", WORKFLOW)
        self.assertIn("TunnelCoreVPN_*_android_universal.apk", WORKFLOW)
        self.assertIn("TunnelCoreVPN_*_android_universal.sha256", WORKFLOW)
        self.assertNotIn("if: ${{ inputs.publish_release }}\n        uses: actions/upload-artifact", WORKFLOW)

    def test_v7_direct_download_uploads_exactly_one_file_per_artifact(self):
        # Regression for GitHub Actions run 40714008835: v7 rejects two
        # files with archive: false even though the APK build is successful.
        blocks = re.findall(
            r"(?m)^      - name: (Upload .* to Actions Artifacts)\n"
            r"((?:^        .*\n|^          .*\n)*)", WORKFLOW
        )
        self.assertEqual(len(blocks), 2)
        for name, body in blocks:
            with self.subTest(name=name):
                self.assertIn("uses: actions/upload-artifact@v7", body)
                self.assertIn("archive: false", body)
                paths = re.findall(r"(?m)^          path: (.+)$", body)
                self.assertEqual(len(paths), 1)
                self.assertNotEqual(paths[0], "|")
        self.assertIn("name: TunnelCoreVPN-Android-Universal-Signed", WORKFLOW)
        self.assertIn("name: TunnelCoreVPN-Android-Universal-SHA256", WORKFLOW)


if __name__ == "__main__":
    unittest.main()
