# TunnelCore VPN

Открытый кроссплатформенный VPN-клиент для сервисов TunnelCore и собственных VPN-конфигураций.

[![Build Status](https://github.com/VnextDevelopment/tunnelcore-vpn/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/VnextDevelopment/tunnelcore-vpn/actions/workflows/deploy.yml?query=branch%3Amain)

[English](README.md) | Русский

## О проекте

TunnelCore VPN создан на базе открытого клиента [Amnezia VPN](https://github.com/amnezia-vpn/amnezia-client). TunnelCore VPN является самостоятельным проектом и не является официальным продуктом или партнёром проекта Amnezia.

Клиент сохраняет сетевую основу исходного проекта и развивает отдельный брендинг TunnelCore и интеграцию с выдачей конфигураций TunnelCore.

## Возможности

- Windows, macOS, Linux, Android и iOS.
- AmneziaWG, WireGuard, OpenVPN, IKEv2, Shadowsocks и функциональность на базе XRay — там, где они поддерживаются конкретной платформой и сборкой.
- Раздельное туннелирование на поддерживаемых платформах.
- Импорт и использование собственных VPN-конфигураций.
- Независимое развитие авторизации и получения конфигураций TunnelCore без переименования самих VPN-протоколов.

> **AmneziaWG** — название VPN-протокола/реализации, поэтому в рамках ребрендинга TunnelCore оно намеренно сохраняется.

## Исходный код и релизы

Репозиторий: https://github.com/VnextDevelopment/tunnelcore-vpn

Готовые версии после публикации находятся в разделе Releases. Тестовые сборки также могут публиковаться как артефакты GitHub Actions.

## Сборка

Клонируйте репозиторий и загрузите подмодули:

```bash
git clone https://github.com/VnextDevelopment/tunnelcore-vpn.git
cd tunnelcore-vpn
git submodule update --init --recursive
```

Основные зависимости: CMake, Qt 6.10+, Conan и инструменты выбранной платформы — Visual Studio для Windows, Xcode для Apple-платформ, Android SDK/NDK для Android и поддерживаемый GCC/Clang для Linux.

Типовая сборка desktop:

```bash
deploy/build.sh --installer all
```

Windows:

```batch
deploy\build.bat --installer all
```

Точные версии инструментов и платформенные зависимости можно посмотреть в build-скриптах и GitHub Actions.

## Исходный проект и авторство

TunnelCore VPN основан на Amnezia VPN. Уведомления об авторских правах, лицензия исходного проекта и лицензии сторонних компонентов сохраняются в репозитории в соответствии с их условиями.

Исходный проект: https://github.com/amnezia-vpn/amnezia-client

## Лицензия

Проект распространяется по GNU General Public License v3.0. См. [LICENSE](LICENSE).

Отдельные сторонние компоненты могут иметь собственные лицензии. См. [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
