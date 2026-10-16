# TunnelCore VPN — cross-platform branding and release checks

This branch separates **user-facing identifiers and installer-owned resources** from the original Amnezia VPN app. Do **not** mass-rename C++ namespaces, third-party dependencies, network protocol names, or translation file prefixes: those are not product branding.

## Identifiers

| Component | Identifier |
| --- | --- |
| Windows service | `TunnelCoreVPN-service` |
| Linux executable / unit | `TunnelCoreVPN` / `TunnelCoreVPN.service` |
| macOS app / helper | `TunnelCoreVPN.app` / `TunnelCoreVPN-service` |
| macOS PF anchor / privileged group | `tcore` / `tcvpn` |
| iOS app | `com.vnextdev.tunnelcorevpn` |
| macOS app | `com.vnextdev.tunnelcorevpn.macos` |
| Apple app group | `group.com.vnextdev.tunnelcorevpn` |
| Apple network extensions | `<platform app ID>.network-extension` |

## Apple Developer prerequisites — not supplied in source control

1. Register both app identifiers and the matching packet-tunnel network extensions in the **TunnelCore** Apple Developer team; enable the Network Extensions and App Groups entitlements.
2. Register `group.com.vnextdev.tunnelcorevpn`, attach it to app and extension targets.
3. Pass the **real** `BUILD_VPN_DEVELOPMENT_TEAM` CMake value. Upstream Amnezia's Team ID is intentionally not used.
4. Set actual release provisioning profile specifiers for app and network extension in `CLIENT_IOS_PROVISIONING_PROFILE_SPECIFIER`, `CLIENT_IOS_NE_PROVISIONING_PROFILE_SPECIFIER`, `CLIENT_MACOS_PROVISIONING_PROFILE_SPECIFIER`, and `CLIENT_MACOS_NE_PROVISIONING_PROFILE_SPECIFIER`. Debug profile variables are separately configurable.
5. After an App Store / Mac App Store listing exists, set `CLIENT_IOS_STORE_URL_FALLBACK` to **TunnelCore's** actual product URL. Before publication the app will not redirect users to Amnezia VPN.

Changing the Apple app ID creates a **separate application identity**; existing test installs with the old app ID will not auto-upgrade. Do not attempt to remove original Amnezia users' data automatically.

## Package acceptance tests

- macOS: Install with and without original Amnezia installed. Inspect `/Applications/TunnelCoreVPN.app` and `/Library/LaunchDaemons/TunnelCoreVPN.plist`. Confirm both VPN apps remain installed; TunnelCore's `tcore` PF anchor and token path never overlap upstream's `amn` resources. Uninstall only TunnelCore and confirm Amnezia still opens and connects.
- Linux: Check installer creates `/opt/TunnelCoreVPN`, `TunnelCoreVPN.service`, `TunnelCoreVPN.desktop`, and branded icon. Install both VPN clients; uninstall TunnelCore and verify original service is untouched.
- iOS: Check the VPN configuration permission dialog, app label, and network extension bundle ID on a device signed with the actual TunnelCore team.
- Windows: Confirm legacy installed TunnelCore versions upgrade in their existing `TunnelCore VPN` directory; never terminate or uninstall Amnezia.
- Android: PR #9 addresses the old notification title, PR #8 fixes keyboard clipping. They are not merged in this branch.

**Compatibility caution:** existing TunnelCore test packages distributed with the **old Amnezia identifiers** may need an explicit manual migration after identifying the installation owner. The revised installer intentionally does not delete those paths or processes: they could belong to original Amnezia. Network routing is inherently shared at OS level; test simultaneous installations, not simultaneous active VPN tunnels.

CI checks only static safety and Android/Windows builds. macOS, iOS and Linux installer behavior must be validated on the corresponding systems before release.
