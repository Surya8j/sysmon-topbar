# SysMon TopBar (macOS)

A lightweight macOS menu bar system monitor — a native Swift port of
[sysmon-topbar](https://github.com/Surya8j/sysmon-topbar) (GNOME Shell extension).

## What it shows

- **CPU view** — one thin vertical bar per core, htop-style colors:
  green (0–30%), cyan (30–60%), yellow (60–85%), red (85–100%)
- **RAM view** — a small rounded gauge filled by usage (same color gradient) plus the used amount, e.g. `▬▭ 7.7G`
- **Left-click** the menu bar item to toggle CPU ↔ RAM
- **Hover** for a tooltip with exact per-core %, memory, and swap values
- **Right-click** (or ⌃-click) for the Quit menu

Polls every 2 seconds (`pollInterval` in `StatusBarController.swift`).
No dependencies — plain AppKit plus Mach/sysctl APIs (`host_processor_info`,
`host_statistics64`, `vm.swapusage`).

## Install (starts at login)

Requires macOS 13+ and the Swift toolchain — Apple's Command Line Tools are
enough, no Xcode needed (if missing, run `xcode-select --install` first).

```sh
git clone https://github.com/Surya8j/sysmon-topbar.git
cd sysmon-topbar/macos
./install.sh
```

This builds the app, copies the binary to `~/Library/Application Support/SysMonTopBar/`,
and registers a LaunchAgent (`~/Library/LaunchAgents/com.surya.sysmontopbar.plist`)
so it launches automatically at every login. To remove everything:

```sh
./uninstall.sh
```

## Run without installing

```sh
swift build -c release
.build/release/SysMonTopBar &
```

The app is menu-bar-only (no Dock icon). Quit via right-click → Quit.
Note: if you quit it, launchd won't restart it until the next login —
re-run `./install.sh` or launch the installed binary to bring it back sooner.
