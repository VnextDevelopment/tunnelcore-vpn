# TunnelCore VPN updates (stable channel)

The client no longer asks Amnezia's gateway for updates. It requests
`GET https://vnextdev.com/api/tunnelcore/updates?platform=windows&version=5.0.2.63`
(the platform is `linux`, `macos`, `android-apk`, `android-play`, `ios`, or `macos-store` as applicable).

The website feed reads **only** the latest non-prerelease GitHub release of
`VnextDevelopment/tunnelcore-vpn`. It checks the exact branded filename and
requires a GitHub-provided SHA-256 digest. No published release / no usable
artifact means `updateAvailable: false`, not a link to upstream Amnezia.
The client additionally validates the version, release/asset URLs, size and
SHA-256 before executing a desktop installer. The download is streamed to a
temporary atomic file; partial files and checksum mismatches are never run.

## Release operation

1. Merge approved changes into `main`. Verify the `Deploy workflow` built
   Windows EXE/MSI and Linux RUN successfully. Record its **Actions run ID**.
2. After reviewing installers, run **Publish TunnelCore VPN release** on the
   `main` branch, supplying `build_run_id` and the version used by the
   installers (currently `5.0.2.<deploy run number>`).
3. The release workflow verifies a successful `main` build, downloads only
   exactly matching first-party installers and publishes a stable release
   `v<version>` with SHA256SUMS.txt. It refuses to overwrite an existing tag.
4. Deploy the matching change to `vnextdevelopment-website` **before**
   publishing releases. Test the feed with an older version and verify that a
   bad digest / unknown platform never produces an install URL.
5. Install an older version on a real Windows/Linux test machine, confirm
   "Check for updates" -> download -> verified installer -> upgrade, with
   existing VPN configuration intact. Verify checksum tampering is refused.

## Other channels

* **Google Play**: Android Play installations open their Play listing; Google
  Play is responsible for actual installation. Only set
  `TUNNELCORE_PLAY_VERSION` on the website after that version is live.
* **Apple**: iOS/macOS store builds use the respective App Store listing,
  never a sideloaded package. Only set `TUNNELCORE_IOS_VERSION` /
  `TUNNELCORE_MACOS_STORE_VERSION` and their official store URLs once live.
* **Android APK**: the feed reserves a first-party
  `TunnelCoreVPN_<version>_android_universal.apk` **signed with the real
  TunnelCore release key**. The current CI Android APKs are unsigned test
  artifacts and MUST NOT be published as updates. After the desktop release
  is published, run **Publish signed Android APK** with the same version; the
  workflow builds the OSS (non-Play) flavor using the TunnelCore release
  keystore, verifies the APK signature with apksigner, and uploads the
  universal package to the matching GitHub release. It fails closed if the
  keystore is not configured or the APK is unsigned. Do not try to update
  a Google Play installation with this APK: Play App Signing may use a
  different certificate. Until a signed universal release exists the feed
  safely reports no update for sideloaded installations.
* **macOS outside App Store**: the feed expects
  `TunnelCoreVPN_<version>_macos_x64.pkg`. Apple CI is presently manual-only,
  so the feed will not show a macOS update before its branded PKG is released.

**Important security limitation**: SHA-256 validates downloaded bytes against
metadata delivered by our website. It does NOT substitute for Authenticode,
Apple Developer ID notarization, Android APK signing, or an independently
verified signed update manifest. Complete platform signing/independent
manifest signing and smoke tests before production automatic desktop installs.
The `mandatory` update flag is a UI recommendation, not currently a
VPN-connection enforcement gate.

For rollback, stop publishing the affected release and issue a higher-version
fixed build. Never repoint an existing version or silently replace release
assets: clients cache versions and checksums.
