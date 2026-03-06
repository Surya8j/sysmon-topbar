# SysMon TopBar

A lightweight, htop-style system monitor for the GNOME Shell top bar. Built for Pop!_OS.

![GNOME 42+](https://img.shields.io/badge/GNOME-42%20|%2043%20|%2044-blue)
![License](https://img.shields.io/badge/license-GPL--3.0-green)
![No sudo](https://img.shields.io/badge/install-no%20sudo-brightgreen)

## Features

**CPU View** — Per-core vertical bar columns with htop color gradient:
- `0–30%` green → `30–60%` cyan → `60–85%` yellow → `85–100%` red
- Dim track behind each core bar

**RAM View** — htop-style bracket bars with vertical pipe fills:
```
Mem[||||||||       7.7G/30.3G]
Swp[||             0M/28.0G ]
```
- Green pipes for RAM, red pipes for swap
- Used/total values shown alongside

**Interactions:**
- **Click** to cycle between CPU ↔ RAM views
- **Hover** for a live-updating tooltip with exact values
- Adapts to system dark/light theme automatically

## Requirements

- Pop!_OS 22.04+ (GNOME Shell 42/43/44)
- No sudo required

## Install

```bash
git clone https://github.com/Surya8j/sysmon-topbar.git
cd sysmon-topbar
chmod +x install.sh
./install.sh
```

Restart GNOME Shell:
- **X11:** `Alt+F2` → type `r` → `Enter`
- **Wayland:** Log out and log back in

### Manual Install

```bash
mkdir -p ~/.local/share/gnome-shell/extensions/sysmon@popbar
cp sysmon@popbar/* ~/.local/share/gnome-shell/extensions/sysmon@popbar/
gnome-extensions enable sysmon@popbar
# Restart GNOME Shell
```

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
# Restart GNOME Shell
```

## Configuration

Edit the constants at the top of `sysmon@popbar/extension.js`:

| Parameter     | Default | Description              |
|---------------|---------|--------------------------|
| `CPU_POLL_MS` | `2000`  | CPU refresh interval     |
| `RAM_POLL_MS` | `2000`  | RAM refresh interval     |

## How It Works

Reads from procfs — zero external dependencies, no spawned processes:
- **CPU:** `/proc/stat` — per-core usage via idle/total deltas
- **RAM:** `/proc/meminfo` — MemTotal, MemAvailable, SwapTotal, SwapFree

Typical resource usage: <1% CPU, ~2MB RAM for the extension itself.

## License

GPL-3.0
