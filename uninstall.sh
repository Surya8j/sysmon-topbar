#!/bin/bash
# SysMon TopBar - Uninstall Script (no sudo required)

EXT_UUID="sysmon@popbar"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"

echo "Uninstalling SysMon TopBar..."

# Disable first
gnome-extensions disable "$EXT_UUID" 2>/dev/null && \
    echo "[✓] Extension disabled" || true

# Remove files
if [ -d "$EXT_DIR" ]; then
    rm -rf "$EXT_DIR"
    echo "[✓] Removed $EXT_DIR"
else
    echo "[!] Extension directory not found"
fi

echo ""
echo "Done. Restart GNOME Shell to complete removal."
echo "  X11:    Alt+F2 → type 'r' → Enter"
echo "  Wayland: Log out and log back in"
