[Deutsch](README.md) | **English**

# WineEts

Sets up **ETS 6.4.1** (KNX software) on **Wine** as a guided whiptail menu in the
terminal (TUI). ETS itself is installed **unchanged** and matches a Windows
installation 1:1; the script only prepares the Wine environment. It modifies
**no** ETS/KNX binaries.

## Scope & approach to problems

The TUI handles **only the installation and setup of the Wine environment**,
**not** ETS itself. The ETS binaries are never touched.

If problems occur **inside ETS** (black window, rendering errors, crashes,
non-working add-ons, etc.), the fix is therefore applied **directly at the Wine
level** with patches to Wine itself — and **never** by modifying ETS. Problems in
ETS are thus fundamentally a Wine matter, not a matter for this installer.

## Upstream Wine fixes for ETS

ETS problems are ultimately Wine problems — they were not worked around in the
tool but **fixed directly in Wine** and contributed upstream. That is why ETS 6
runs on unmodified stock Wine from **Wine 11.10** onwards; a patched Wine is no
longer needed.

Contributed merge requests at [WineHQ](https://gitlab.winehq.org/wine/wine) regarding ETS:

| MR | Fix | ETS relevance | Status |
|----|-----|---------------|--------|
| [!10604](https://gitlab.winehq.org/wine/wine/-/merge_requests/10604) | `ntoskrnl`/`cfgmgr32`: device-tree properties + `CM_Get_Parent` | KNX USB licence dongle is detected | merged — Wine 11.10 |
| [!10565](https://gitlab.winehq.org/wine/wine/-/merge_requests/10565) | `shcore`: Set/GetCurrentProcessExplicitAppUserModelID | taskbar identity | merged — Wine 11.7 |
| [!10329](https://gitlab.winehq.org/wine/wine/-/merge_requests/10329) | `windowscodecs` (WIC): BlackWhite pixel format | image/icon decoding | merged — Wine 11.5 |
| [!10301](https://gitlab.winehq.org/wine/wine/-/merge_requests/10301) | `hidclass.sys`: correct DeviceType for HID PDOs | USB devices / dongle | merged — Wine 11.5 |
| [!10300](https://gitlab.winehq.org/wine/wine/-/merge_requests/10300) | `jscript`: empty string → NULL in `GetScriptDispatch` | scripting / WebView2 | merged — Wine 11.5 |

If you run into bugs/problems, feel free to document them so I can patch them in Wine upstream.

## Known issues

- At high resolutions performance can suffer (no hardware rendering yet)
- Some DCAs/add-ons do not run (a concrete list is in progress)
- The 32-bit compatibility mode does not work cleanly, and neither do old 32-bit plugins

## Requirements

- Linux with `wine` **11.10 or newer** (development branch)
- `whiptail` (package `newt`/`libnewt`)
- The remaining packages (winetricks, fonttools, cabextract, …) are installed
  automatically by step 1 — Arch, Debian/Ubuntu, Fedora and openSUSE are supported.
- The ETS `setup.exe` (you must obtain it yourself from the KNX Association)

## Mac / macOS support

- work in progress

## Usage

```bash
./wineets.sh
```

Work through steps **1 to 11** in order in the menu (or **A** for all of 1–10 at
once). Each step has its own CHECK block that shows whether it completed cleanly.
Details go into a log file (the path is shown at startup).

**Language:** the interface is available in German and English — auto-detected
from your locale (`$LANG`), forceable with `WINEETS_LANG=en` or `WINEETS_LANG=de`,
or switchable at runtime via menu item **S**.

### The steps at a glance

| # | Step |
|---|------|
| 1 | Install system packages |
| 2 | Check Wine version (≥ 11.10) |
| 3 | Create Wine prefix (64-bit) |
| 4 | .NET Framework 4.0 + 4.8 |
| 5 | VC++ runtime + GDI+ + Windows fonts |
| 6 | Install ETS 6.4.1 |
| 7 | Fonts (Segoe UI / MDL2 replacement) |
| 8 | Firewall (KNXnet/IP, UDP 3671) |
| 9 | WPF software mode + desktop integration |
| 10 | USB licence dongle (udev rule) |
| 11 | Start ETS |

The Wine prefix defaults to `~/.wine-ets6` and can be changed in the menu (item
**P**) or via the `WINEPREFIX` environment variable.

## Files

- `wineets.sh` — the main TUI script
- `make-mdl2.py` — generates a minimal Segoe MDL2 replacement for the title-bar
  icons (requires `python-fonttools`)
- `release.sh` — tags a release matching the `VERSION` in `wineets.sh`

## License

[GPL-3.0-or-later](LICENSE) — © 2026 Robert Gerigk

*ETS® and KNX® are trademarks of the KNX Association. This project is not
affiliated with the KNX Association and does not distribute any ETS software.*
