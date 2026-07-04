#!/bin/sh
# Stop SysMonTopBar, unregister the LaunchAgent, and remove installed files.
set -e

LABEL="com.surya.sysmontopbar"
APP_DIR="$HOME/Library/Application Support/SysMonTopBar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "Unloading LaunchAgent"
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true

echo "Removing $PLIST"
rm -f "$PLIST"

echo "Removing $APP_DIR"
rm -rf "$APP_DIR"

pkill -x SysMonTopBar 2>/dev/null || true

echo "Done. SysMonTopBar removed."
