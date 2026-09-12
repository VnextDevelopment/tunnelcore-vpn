# TunnelCore VPN

Open-source cross-platform VPN client for TunnelCore services and self-hosted VPN configurations.

[![Build Status](https://github.com/VnextDevelopment/tunnelcore-vpn/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/VnextDevelopment/tunnelcore-vpn/actions/workflows/deploy.yml?query=branch%3Amain)

[English](README.md) | [Русский](README_RU.md)

## About

TunnelCore VPN is a derivative of the open-source [Amnezia VPN](https://github.com/amnezia-vpn/amnezia-client) client. TunnelCore VPN is an independent project and is not affiliated with or endorsed by the Amnezia project.

The client keeps the upstream networking foundation while providing TunnelCore branding and integration for TunnelCore account/configuration delivery.

## Features

- Windows, macOS, Linux, Android and iOS support.
- AmneziaWG, WireGuard, OpenVPN, IKEv2, Shadowsocks and XRay-based functionality inherited from the upstream client where supported by the platform/build.
- Split tunneling on supported platforms.
- Support for imported/self-hosted VPN configurations.
- TunnelCore-specific client integration can be developed independently from the VPN protocol implementations.

> **AmneziaWG** is the name of the VPN protocol/implementation and is intentionally not renamed as part of the TunnelCore product branding.

## Source and releases

Repository: https://github.com/VnextDevelopment/tunnelcore-vpn

Releases, when published, are available from the repository's Releases section. Development builds may also be available as GitHub Actions artifacts.

## Building

Clone the repository and initialize all submodules:

```bash
git clone https://github.com/VnextDevelopment/tunnelcore-vpn.git
cd tunnelcore-vpn
git submodule update --init --recursive
```

Main build requirements include CMake, Qt 6.10+, Conan and the platform-specific toolchain (Visual Studio on Windows, Xcode on Apple platforms, Android SDK/NDK for Android, and a supported GCC/Clang toolchain on Linux).

Typical desktop build:

```bash
deploy/build.sh --installer all
```

Windows:

```batch
deploy\build.bat --installer all
```

See the build scripts and GitHub Actions workflows for the exact CI toolchain and platform-specific dependencies.

## Upstream and attribution

TunnelCore VPN is based on Amnezia VPN. Copyright notices and licensing information from the upstream project and bundled third-party components are retained in the source tree as required by their respective licenses.

Upstream project: https://github.com/amnezia-vpn/amnezia-client

## License

The project is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

Third-party components may be distributed under their own licenses. See [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
