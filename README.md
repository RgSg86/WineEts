# WineEts

Richtet die **ETS 6.4.1** (KNX-Software) unter **Wine** ein — als geführtes
whiptail-Menü im Terminal (TUI). Die ETS selbst wird **unverändert** installiert
und entspricht 1:1 einer Windows-Installation; das Skript bereitet nur die
Wine-Umgebung vor. Es modifiziert **keine** ETS/KNX-Binaries.

## Voraussetzungen

- Linux mit `wine` **11.10 oder neuer** (Development-Branch)
- `whiptail` (Paket `newt`/`libnewt`)
- Die restlichen Pakete (winetricks, fonttools, cabextract, …) installiert
  Schritt 1 automatisch — unterstützt werden Arch, Debian/Ubuntu, Fedora und openSUSE.
- Die ETS-`setup.exe` (musst du selbst von der KNX Association beziehen)
- Optional: KNX-USB-Lizenz-Dongle

## Nutzung

```bash
./wineets.sh
```

Im Menü die Schritte **1 bis 11** der Reihe nach abarbeiten (oder **A** für alle
1–10 am Stück). Jeder Schritt hat einen eigenen PRÜFEN-Block, der zeigt, ob er
sauber durchgelaufen ist. Details landen in einer Logdatei (Pfad wird beim Start
angezeigt).

### Die Schritte im Überblick

| # | Schritt |
|---|---------|
| 1 | Systempakete installieren |
| 2 | Wine-Version prüfen (≥ 11.10) |
| 3 | Wine-Prefix anlegen (64-bit) |
| 4 | .NET Framework 4.0 + 4.8 |
| 5 | VC++ Runtime + GDI+ + Windows-Schriften |
| 6 | ETS 6.4.1 installieren |
| 7 | Schriftarten (Segoe UI / MDL2-Ersatz) |
| 8 | Firewall (KNXnet/IP, UDP 3671) |
| 9 | WPF-Software-Modus + Desktop-Integration |
| 10 | USB-Lizenz-Dongle (udev-Regel) |
| 11 | ETS starten |

Der Wine-Prefix ist standardmäßig `~/.wine-ets6` und lässt sich im Menü (Punkt **P**)
oder über die Umgebungsvariable `WINEPREFIX` ändern.

## Dateien

- `wineets.sh` — das Haupt-TUI-Skript
- `make-mdl2.py` — erzeugt einen minimalen Segoe-MDL2-Ersatz für die
  Titelleisten-Icons (benötigt `python-fonttools`)
- `release.sh` — taggt einen Release passend zur `VERSION` in `wineets.sh`

## Lizenz

[GPL-3.0-or-later](LICENSE) — © 2026 Robert Gerigk

*ETS® und KNX® sind Marken der KNX Association. Dieses Projekt steht in keiner
Verbindung zur KNX Association und liefert keine ETS-Software aus.*
