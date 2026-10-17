#!/bin/bash
# Install only the independent TunnelCore service and desktop entry.
set -euo pipefail
APP_NAME=TunnelCoreVPN
APP_PATH="/opt/$APP_NAME"
UNIT="/etc/systemd/system/$APP_NAME.service"

if [ "$(id -u)" -ne 0 ]; then
    echo "TunnelCore installer must run as root" >&2
    exit 1
fi
if [ ! -x "$APP_PATH/bin/TunnelCoreVPN" ] || [ ! -x "$APP_PATH/bin/TunnelCoreVPN-service" ]; then
    echo "TunnelCore binaries not found in $APP_PATH/bin" >&2
    exit 1
fi

mkdir -p "/var/log/$APP_NAME"
# Stop our existing daemon for upgrades, not any upstream service.
systemctl stop "$APP_NAME.service" 2>/dev/null || true
install -m 0644 "$APP_PATH/$APP_NAME.service" "$UNIT"
systemctl daemon-reload
systemctl enable --now "$APP_NAME.service"
ln -sfn "$APP_PATH/bin/$APP_NAME" "/usr/local/bin/$APP_NAME"
install -m 0644 "$APP_PATH/$APP_NAME.desktop" "/usr/share/applications/$APP_NAME.desktop"
install -m 0644 "$APP_PATH/$APP_NAME.png" "/usr/share/pixmaps/$APP_NAME.png"
echo "TunnelCore VPN installed"
