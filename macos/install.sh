#!/bin/sh
# Build SysMonTopBar, install it to a stable location, and register a
# LaunchAgent so it starts automatically at login.
set -e
cd "$(dirname "$0")"

LABEL="com.surya.sysmontopbar"
APP_DIR="$HOME/Library/Application Support/SysMonTopBar"
BIN="$APP_DIR/SysMonTopBar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "Building..."
swift build -c release

echo "Installing binary to $BIN"
mkdir -p "$APP_DIR"
cp .build/release/SysMonTopBar "$BIN"

echo "Writing LaunchAgent $PLIST"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Stop any manually launched instance so we don't end up with two status items.
pkill -x SysMonTopBar 2>/dev/null || true

echo "Loading LaunchAgent"
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Done. SysMonTopBar is running and will start automatically at login."
echo "To remove: ./uninstall.sh"
