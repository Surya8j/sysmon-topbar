# SysMon TopBar

See your Mac's CPU and memory usage at a glance, right in the menu bar. A lightweight, native Swift app — no dependencies, no Dock icon.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

## What you get

- **CPU view** — one thin vertical bar per core, htop-style colors: green (0–30%), cyan (30–60%), yellow (60–85%), red (85–100%)
- **RAM view** — a small rounded gauge filled by usage (same color gradient) plus the used amount, e.g. `▬▭ 7.7G`
- **GPU view** — overall GPU utilization as plain text, e.g. `GPU 14%`
- **Left-click** the menu bar item to cycle CPU → RAM → GPU
- **Hover** for a tooltip with exact per-core %, memory, swap, and GPU values
- **Right-click** (or ⌃-click) for the Quit menu

It's very light on your system — plain AppKit plus Mach/sysctl APIs, polling every 2 seconds.

## Install (starts at login)

Requires macOS 13+ and the Swift toolchain — Apple's Command Line Tools are enough, no Xcode needed (if missing, run `xcode-select --install` first).

```sh
git clone https://github.com/Surya8j/sysmon-topbar.git
cd sysmon-topbar/macos
./install.sh
```

This builds the app, copies the binary to `~/Library/Application Support/SysMonTopBar/`, and registers a LaunchAgent so it launches automatically at every login.

## Uninstall

```sh
cd sysmon-topbar/macos
./uninstall.sh
```

## Run without installing

```sh
cd macos
swift build -c release
.build/release/SysMonTopBar &
```

See [macos/README.md](macos/README.md) for more details.

## License

GPL-3.0
