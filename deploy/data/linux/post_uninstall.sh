#!/bin/bash
# Remove TunnelCore integrations only. Do not touch upstream AmneziaVPN.
set -euo pipefail
APP_NAME=TunnelCoreVPN
APP_BINARY="/opt/$APP_NAME/bin/$APP_NAME"
UNIT="/etc/systemd/system/$APP_NAME.service"

if [ "$(id -u)" -ne 0 ]; then
    echo "TunnelCore uninstaller must run as root" >&2
    exit 1
fi

systemctl disable --now "$APP_NAME.service" 2>/dev/null || true
rm -f "$UNIT"
systemctl daemon-reload

# Remove only symlinks which still point to our own binary.
for link in "/usr/local/bin/$APP_NAME" "/usr/local/sbin/$APP_NAME"; do
    if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$APP_BINARY" ]; then
        rm -f "$link"
    fi
done
rm -f "/usr/share/applications/$APP_NAME.desktop"
rm -f "/usr/share/pixmaps/$APP_NAME.png"
# The IFW package manager owns /opt/TunnelCoreVPN and handles its removal.
# Preserve user profiles and unrelated VPN apps.
echo "TunnelCore VPN uninstalled"
