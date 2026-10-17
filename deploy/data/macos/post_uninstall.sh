#!/bin/bash
# Uninstall only TunnelCore-owned resources; do not touch AmneziaVPN.
set -euo pipefail

APP_NAME=TunnelCoreVPN
DAEMON_PLIST="/Library/LaunchDaemons/${APP_NAME}.plist"
APP_PATH="/Applications/${APP_NAME}.app"
DATA_DIR="/Library/Application Support/${APP_NAME}/pf"

if [ "$(id -u)" -ne 0 ]; then
    echo "Must run as root" >&2
    exit 1
fi

if [ -f "$DAEMON_PLIST" ]; then
    launchctl bootout system "$DAEMON_PLIST" || true
    rm -f "$DAEMON_PLIST"
fi

# Only release the TunnelCore PF anchor and reference token.
pfctl -q -a tcore -F all 2>/dev/null || true
if [ -f "$DATA_DIR/pf.token" ]; then
    token=$(cat "$DATA_DIR/pf.token")
    if [ -n "$token" ]; then pfctl -X "$token" 2>/dev/null || true; fi
    rm -f "$DATA_DIR/pf.token"
fi

rm -rf "$APP_PATH"
rm -rf "$DATA_DIR"
rmdir "/Library/Application Support/${APP_NAME}" 2>/dev/null || true
# Preserve user settings, the shared PF ruleset, and other VPN services.
echo "TunnelCore VPN uninstalled"
