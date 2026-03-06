#!/bin/bash
# SysMon TopBar - Install Script (no sudo required)

set -e

EXT_UUID="sysmon@popbar"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"

echo "╔════════════════════════════════════════╗"
echo "║     SysMon TopBar - Installer          ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if already installed
if [ -d "$EXT_DIR" ]; then
    echo "[!] Extension already exists at $EXT_DIR"
    read -p "    Overwrite? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Aborted."
        exit 0
    fi
    rm -rf "$EXT_DIR"
fi

# Get script directory (where the extension files are)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/sysmon@popbar"

if [ ! -f "$SRC_DIR/extension.js" ]; then
    echo "[ERROR] extension.js not found in $SRC_DIR"
    echo "        Make sure you run this from the extracted folder."
    exit 1
fi

# Create target directory and copy files
mkdir -p "$EXT_DIR"
cp "$SRC_DIR/metadata.json" "$EXT_DIR/"
cp "$SRC_DIR/extension.js" "$EXT_DIR/"
cp "$SRC_DIR/stylesheet.css" "$EXT_DIR/"

echo "[✓] Files copied to $EXT_DIR"

# Enable the extension
gnome-extensions enable "$EXT_UUID" 2>/dev/null && \
    echo "[✓] Extension enabled" || \
    echo "[!] Could not auto-enable. Enable manually (see below)."

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  Installation complete!                ║"
echo "╠════════════════════════════════════════╣"
echo "║  Restart GNOME Shell to activate:      ║"
echo "║                                        ║"
echo "║  X11:    Alt+F2 → type 'r' → Enter     ║"
echo "║  Wayland: Log out and log back in      ║"
echo "║                                        ║"
echo "║  If not auto-enabled, run:             ║"
echo "║  gnome-extensions enable sysmon@popbar ║"
echo "╚════════════════════════════════════════╝"
