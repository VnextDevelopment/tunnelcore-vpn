# Google Play release: TunnelCore VPN

## App identity

- Display name: `TunnelCore VPN`.
- Google Play package ID (`applicationId`): `com.vnextdev.tunnelcorevpn`.
- Android Kotlin/Java `namespace`: `org.amnezia.vpn` (intentionally unchanged: it is **not** the Play package ID).
- The app remains free to install; access to TunnelCore VPN can depend on subscription entitlement.

The package ID is reserved in the VNext Development Google Play Console. **Do not change it after the first upload** or the app will be treated as a different app.

The previous `com.tunnelcore.vpn` ID is not an upgrade path to the Play listing. APKs installed with that ID are separate Android apps; they cannot be updated in place by the new Play package. Plan migration/support messaging for existing sideloaded APK users.

Two source values must stay synchronized:

1. `client/android/build.gradle.kts`: `defaultConfig.applicationId` (actual Android package).
2. `client/cmake/branding/android.cmake`: `CLIENT_ANDROID_PACKAGE` (the store/package lookup identifier shown by the C++ client).

GitHub Actions checks these values in Android PR CI and in the Play release workflow. Do **not** rename `org.amnezia.vpn` Kotlin/Java packages as part of this app ID change; that requires a separate migration.

## Build an Android App Bundle for Google Play

Run the **Android Play Release** workflow (`.github/workflows/android-play-release.yml`) from the intended commit/branch. It builds the `play` flavor with `--play --aab --sign` and uploads a `TunnelCoreVPN-Android-Play-AAB` artifact.

The workflow requires these GitHub Actions secrets to be configured securely:

- `ANDROID_RELEASE_KEYSTORE_BASE64`
- `ANDROID_RELEASE_KEYSTORE_PASSWORD`
- `ANDROID_RELEASE_KEY_ALIAS`

Use the **upload key** intended for Google Play App Signing, keep the keystore backed up, and never commit keys or passwords. The workflow checks that both ARM64 and x86_64 native libraries are present. APK artifacts produced by standard PR CI are for testing, not for uploading as the Play App Bundle.

## Before requesting public release

- Confirm Google Play organization/representative verification is completed.
- Upload the signed Play AAB to **Internal testing** first and install it from Google Play.
- Verify sign-in, VPN permission/connectivity, subscription entitlement, and upgrade/reinstall behavior.
- Complete the VPN Service declaration and app content forms (Data safety, privacy policy, content rating, target audience, screenshots, store listing).
- Check the **Play** flavor's subscription/purchase flow against current Google Play payments rules. The Android client currently uses a consumption-only flow and must not route users to an external payment website or bot from within the Play app where that would violate Google Play policy.
- Verify app signing certificate fingerprints if any backend/auth integrations bind their identity to the signing certificate.
