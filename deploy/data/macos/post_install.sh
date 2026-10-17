#!/bin/bash
# Postinstall for TunnelCore only; do not touch AmneziaVPN.
set -euo pipefail

APP_NAME=TunnelCoreVPN
SERVICE_LABEL=TunnelCoreVPN-service
SERVICE_GROUP=tcvpn
APP_PATH="/Applications/${APP_NAME}.app"
PLIST_NAME="${APP_NAME}.plist"
DAEMON_PLIST="/Library/LaunchDaemons/${PLIST_NAME}"
LOG_DIR="/var/log/${APP_NAME}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Must run as root" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/post-install.log" 2>&1
echo "$(date) Installing ${APP_NAME}"

# Migrate only a localized TunnelCore bundle, never the upstream app.
if [ -d "/Applications/${APP_NAME}.localized/${APP_NAME}.app" ]; then
    mv "/Applications/${APP_NAME}.localized/${APP_NAME}.app" "$APP_PATH"
    rmdir "/Applications/${APP_NAME}.localized" 2>/dev/null || true
fi

PLIST_SOURCE="$APP_PATH/Contents/Resources/$PLIST_NAME"
if [ ! -f "$PLIST_SOURCE" ] || [ ! -x "$APP_PATH/Contents/MacOS/$SERVICE_LABEL" ]; then
    echo "TunnelCore bundle or helper is missing: $APP_PATH" >&2
    exit 1
fi

# On upgrade, stop exclusively our own launch daemon.
if [ -f "$DAEMON_PLIST" ]; then
    launchctl bootout system "$DAEMON_PLIST" || true
fi

if ! dscl . -read "/Groups/$SERVICE_GROUP" >/dev/null 2>&1; then
    next_gid=$(dscl . -list /Groups PrimaryGroupID 2>/dev/null | awk '{print $2}' | sort -n | awk '$1>=500{g=$1} END{print (g?g+1:501)}')
    dscl . -create "/Groups/$SERVICE_GROUP"
    dscl . -create "/Groups/$SERVICE_GROUP" PrimaryGroupID "$next_gid"
    dscl . -create "/Groups/$SERVICE_GROUP" RealName "TunnelCore VPN Service Group"
fi

chown -R root:wheel "$APP_PATH"
chmod -R a-w "$APP_PATH"
cp -f "$PLIST_SOURCE" "$DAEMON_PLIST"
chown root:wheel "$DAEMON_PLIST"
chmod 644 "$DAEMON_PLIST"
launchctl bootstrap system "$DAEMON_PLIST"
launchctl enable "system/$SERVICE_LABEL" || true
launchctl kickstart -k "system/$SERVICE_LABEL" || true
open -a "$APP_PATH" || true
echo "$(date) TunnelCore installed"
