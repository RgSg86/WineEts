**Deutsch** | [English](README.en.md)

# WineEts

Richtet die **ETS 6.4.1** (KNX-Software) unter **Wine** ein als geführtes
whiptail-Menü im Terminal (TUI). Die ETS selbst wird **unverändert** installiert
und entspricht 1:1 einer Windows-Installation, das Skript bereitet nur die
Wine-Umgebung vor. Es modifiziert **keine** ETS/KNX-Binaries.

## Umfang & Vorgehen bei Problemen

Das TUI behandelt ausschließlich die **Installation und Einrichtung der
Wine-Umgebung**, **nicht** die ETS selbst. Die ETS-Binaries werden zu keinem
Zeitpunkt angefasst.

Treten **innerhalb der ETS** Probleme auf (schwarzes Fenster, Render-Fehler,
Abstürze, nicht funktionierende Addons o. Ä.), wird die Lösung deshalb **direkt auf Wine-Ebene** angesetzt mit Patches an Wine selbst und **nie** durch Eingriffe in die ETS. Fehler in der ETS sind damit grundsätzlich ein Wine-Thema, kein Thema für diesen Installer. 

## Upstream-Wine-Fixes für ETS

ETS-Probleme <--> Wine Probleme wurden nicht im Tool umgangen, sondern **direkt in
Wine behoben** und upstream beigetragen. Deshalb läuft ETS 6 ab **Wine 11.10**
auf unverändertem Stock-Wine, ein gepatchtes Wine ist nicht mehr nötig.

Beigetragene Merge Requests bei [WineHQ](https://gitlab.winehq.org/wine/wine) bezüglich der ETS:

| MR | Fix | ETS-Bezug | Status |
|----|-----|-----------|--------|
| [!10604](https://gitlab.winehq.org/wine/wine/-/merge_requests/10604) | `ntoskrnl`/`cfgmgr32`: Device-Tree-Properties + `CM_Get_Parent` | KNX-USB-Lizenz-Dongle wird erkannt | gemergt — Wine 11.10 |
| [!10565](https://gitlab.winehq.org/wine/wine/-/merge_requests/10565) | `shcore`: Set/GetCurrentProcessExplicitAppUserModelID | Taskbar-Identität | gemergt — Wine 11.7 |
| [!10329](https://gitlab.winehq.org/wine/wine/-/merge_requests/10329) | `windowscodecs` (WIC): BlackWhite-Pixelformat | Bild-/Icon-Dekodierung | gemergt — Wine 11.5 |
| [!10301](https://gitlab.winehq.org/wine/wine/-/merge_requests/10301) | `hidclass.sys`: korrekter DeviceType für HID-PDOs | USB-Geräte / Dongle | gemergt — Wine 11.5 |
| [!10300](https://gitlab.winehq.org/wine/wine/-/merge_requests/10300) | `jscript`: leerer String → NULL in `GetScriptDispatch` | Scripting / WebView2 | gemergt — Wine 11.5 |


Bei erkannten Fehlern/Problemen können diese gerne dokumentiert werden, damit ich diese in Wine selber patchen kann.

## Bekannte Probleme:

- Bei hohen Auflösungen kann die Performance leiden (bisher kein Hardware-Rendering)
- Einige DCA/ Addons laufen nicht (konkrete Liste ist in Bearbeitung)
- Der 32-Bit-Kompatibilitätsmodus funktioniert nicht sauber, ebenso alte 32bit Plugins. 

## Voraussetzungen

- Linux mit `wine` **11.10 oder neuer** (Development-Branch)
- `whiptail` (Paket `newt`/`libnewt`)
- Die restlichen Pakete (winetricks, fonttools, cabextract, …) installiert
  Schritt 1 automatisch — unterstützt werden Arch, Debian/Ubuntu, Fedora und openSUSE.
- Die ETS-`setup.exe` (musst du selbst von der KNX Association beziehen)

## Mac / macOS Support

- ist in Bearbeitung

## Nutzung

```bash
./wineets.sh
```

Im Menü die Schritte **1 bis 11** der Reihe nach abarbeiten (oder **A** für alle
1–10 am Stück). Jeder Schritt hat einen eigenen PRÜFEN-Block, der zeigt, ob er
sauber durchgelaufen ist. Details landen in einer Logdatei (Pfad wird beim Start
angezeigt).

**Sprache:** Die Oberfläche gibt es auf Deutsch und Englisch — automatisch aus
deiner Locale (`$LANG`) gewählt, per `WINEETS_LANG=en` bzw. `WINEETS_LANG=de`
erzwingbar oder zur Laufzeit über Menüpunkt **S** umschaltbar.

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
