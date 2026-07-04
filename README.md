# SysMon TopBar

See your computer's CPU and memory usage at a glance, right in the top bar. Made for Pop!_OS and other GNOME Linux desktops.

![GNOME 41+](https://img.shields.io/badge/GNOME-41%E2%80%9346-blue)
![License](https://img.shields.io/badge/license-GPL--3.0-green)
![No sudo](https://img.shields.io/badge/install-no%20sudo-brightgreen)

> 🍎 **On a Mac?** The native macOS version lives on the [`main`](https://github.com/Surya8j/sysmon-topbar/tree/main) branch.

## What you get

- **CPU view** — a tiny bar for each CPU core. Bars turn from green to yellow to red as your computer works harder.
- **Memory view** — how much RAM you're using, htop-style: `Mem[||||    7.7G/30.3G]`
- **Click** the display to switch between the two views.
- **Hover** over it to see exact numbers.

It's very light on your system (under 1% CPU, ~2MB RAM), matches your dark/light theme, and needs no admin password.

## Install

```bash
git clone -b linux https://github.com/Surya8j/sysmon-topbar.git
cd sysmon-topbar
./install.sh
```

Then restart GNOME Shell to see it:
- **X11:** press `Alt+F2`, type `r`, press `Enter`
- **Wayland:** log out and log back in

## Uninstall

```bash
./uninstall.sh
```

…and restart GNOME Shell the same way.

## Tweaks

Want it to update faster or slower? Change `CPU_POLL_MS` / `RAM_POLL_MS` (milliseconds, default `2000` = 2 seconds) at the top of `sysmon@popbar/extension.js`.

<details>
<summary>How it works / manual install</summary>

The extension simply reads `/proc/stat` (CPU) and `/proc/meminfo` (RAM) — no external tools, no background processes.

Manual install, if you prefer not to use the script:

```bash
mkdir -p ~/.local/share/gnome-shell/extensions/sysmon@popbar
cp sysmon@popbar/metadata.json sysmon@popbar/stylesheet.css \
   ~/.local/share/gnome-shell/extensions/sysmon@popbar/

# GNOME 45–46:
cp sysmon@popbar/extension-modern.js \
   ~/.local/share/gnome-shell/extensions/sysmon@popbar/extension.js
# GNOME 41–44: use extension-legacy.js instead

gnome-extensions enable sysmon@popbar
# Restart GNOME Shell
```
</details>

## License

GPL-3.0
