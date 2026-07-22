#!/usr/bin/env bash
#
# wineets.sh - WineEts: set up ETS 6.4.1 on Wine (TUI, DE/EN)
#
# Automates setting up a WINE environment for installing ETS 6.4.1.
# ETS is installed unchanged and matches a Windows installation 1:1.
#
# Usage: whiptail menu. Steps run individually or all at once, each with its own CHECK block.
# Language: auto-detected from $LANG (de* -> German, otherwise English), forceable via
#           WINEETS_LANG=en|de, switchable at runtime from the menu (item S).
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Robert Gerigk
#
# This program is free software under the GNU GPL v3 or later.
# The full license text is in the LICENSE file.
#
# PRAISE THE OMNISSIAH!
#
#
set -uo pipefail

# ---------------------------------------------------------------------------
# Global configuration
# ---------------------------------------------------------------------------
VERSION="0.2.0"
WINEPREFIX_DEFAULT="$HOME/.wine-ets6"
WINEPREFIX="${WINEPREFIX:-$WINEPREFIX_DEFAULT}"
export WINEPREFIX
export WINEARCH=win64

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
MDL2_SCRIPT="$SCRIPT_DIR/make-mdl2.py"
LOGFILE="${TMPDIR:-/tmp}/wineets-$(date +%Y%m%d-%H%M%S).log"

# whiptail size
WT_HEIGHT=20
WT_WIDTH=76
WT_MENU_HEIGHT=13

# ---------------------------------------------------------------------------
# i18n: language selection + catalog + translation function t()
# ---------------------------------------------------------------------------
# Determine the language: WINEETS_LANG takes precedence, otherwise $LANG.
# de* -> German, everything else -> English (English is the global default).
detect_lang() {
    local l="${WINEETS_LANG:-${LANG:-}}"
    case "${l,,}" in
        de*) echo de ;;
        *)   echo en ;;
    esac
}
LANG_SEL="$(detect_lang)"

# Only the German catalog is complete; keys missing from the English one fall
# back to German (values that are identical in both languages - winetricks
# commands, DPI percentages - are therefore listed only once, in T_de).
declare -A T_de=(
    [backtitle]='WineEts  -  ETS6 unter Wine einrichten  v%s'
    [chk_title]='Schritt %s: PRÜFEN'
    [result_ok]='OK - Schritt erfolgreich.\n\n%s'
    [result_fail]='FEHLER - Schritt nicht (vollständig) erfolgreich.\n\n%s\n\nDetails im Log:\n%s'
    [wi_running]='(läuft, Details im Log: %s)'
    [wi_done]='fertig.'
    [chk_line_ok]='OK    %s'
    [chk_line_miss]='FEHLT %s'

    [s1_title]='Schritt 1: Pakete'
    [s1_pacman]='Installiere Systempakete via pacman ...'
    [s1_apt]='Installiere Systempakete via apt ...'
    [s1_dnf]='Installiere Systempakete via dnf ...'
    [s1_zypper]='Installiere Systempakete via zypper ...'
    [s1_unknown]='Distribution nicht erkannt.\n\nBitte manuell installieren:\nwine winetricks python3-fonttools cabextract unzip wget p7zip msitools'

    [s2_title]='Schritt 2: Wine-Version'
    [s2_notfound]='nicht gefunden'
    [s2_ok]='Installiertes Wine: %s\n\nOK - Version 11.10 oder höher. Weiter mit Schritt 3.'
    [s2_hint_arch]='sudo pacman -Syu wine'
    [s2_hint_debian]='WineHQ-Repo einrichten und winehq-devel installieren\n(NICHT winehq-stable, das ist 10.x und zu alt).\nSiehe Anleitung Schritt 2.'
    [s2_hint_fedora]='WineHQ-Repo hinzufügen, dann: sudo dnf install winehq-devel'
    [s2_hint_opensuse]='WineHQ-Repo hinzufügen, dann: sudo zypper install winehq-devel'
    [s2_hint_other]='Wine 11.10+ aus dem WineHQ-devel-Repo installieren.'
    [s2_body]='Installiertes Wine: %s\n\nETS6 braucht Wine 11.10 oder neuer (Development-Branch).\n\nEmpfohlenes Update:\n%s\n\nDieser Schritt ändert Systemquellen NICHT automatisch, da das\ndistro- und versionsabhängig ist. Bitte Wine aktualisieren und\ndann diesen Schritt erneut prüfen.'

    [s3_title]='Schritt 3: Wine-Prefix'
    [s3_creating]='Erzeuge 64-bit Wine-Prefix unter:\n%s'
    [s3_prefix]='Prefix: %s'

    [s4_title]='Schritt 4: .NET'
    [s4_confirm]='Jetzt werden .NET 4.0 und 4.8 via winetricks installiert.\n\nDas dauert MEHRERE MINUTEN je Runtime (Download + Installation\nder echten Microsoft-Installer). Bitte Geduld, nicht abbrechen.\n\nFortfahren?'
    [s4_mono]='winetricks remove_mono (entfernt Wine-Mono) ...'
    [s4_dotnet40]='winetricks dotnet40 (mehrere Minuten) ...'
    [s4_dotnet48]='winetricks dotnet48 (mehrere Minuten) ...'
    [s4_chk_ok]='.NET 4.x vorhanden (clr.dll gefunden).'
    [s4_chk_fail]='.NET fehlt - dotnet48 nicht durchgelaufen. Ggf. Schritt 4 wiederholen.'

    [s5_title_vc]='Schritt 5: VC++'
    [s5_title_fonts]='Schritt 5: Schriften'
    [s5_vcrun]='winetricks vcrun2022 ...'
    [s5_gdiplus]='winetricks gdiplus ...'
    [s5_win10]='winetricks win10 (Windows-Version) ...'
    [s5_allfonts]='winetricks allfonts (Windows-Standardschriften, dauert etwas) ...'
    [s5_chk_ok]='vcruntime140.dll vorhanden.'
    [s5_chk_fail]='vcruntime140.dll fehlt - vcrun2022 nicht durchgelaufen.'

    [s6_title]='Schritt 6: ETS'
    [s6_reinstall]='ETS6N.exe ist bereits im Prefix vorhanden.\n\nNeu installieren (setup.exe erneut ausführen)?'
    [s6_found]='Gefundene Setup-Datei:\n%s\n\nDiese verwenden?'
    [s6_choose_title]='Schritt 6: Setup-Datei wählen'
    [s6_choose_menu]='Mehrere ETS-Setups gefunden:'
    [s6_path_title]='Schritt 6: Pfad zur setup.exe'
    [s6_path_prompt]='Vollständigen Pfad zur ETS6-Setup.exe eingeben:'
    [s6_notfound]='Datei nicht gefunden:\n%s'
    [s6_installer]='Der ETS-Installer wird jetzt gestartet:\n%s\n\nBitte durch den grafischen Installer klicken.\nNach Abschluss dieses Fenster wieder aufsuchen (das Skript wartet, bis der Installer beendet ist).'
    [s6_chk_ok]='ETS6N.exe installiert.'
    [s6_chk_fail]='ETS6N.exe fehlt - Installer nicht durchgelaufen oder anderer Zielpfad.'

    [s7_title]='Schritt 7: Schriften'
    [s7_nofont]='Keine Ersatz-Sans-Schrift gefunden (Liberation/DejaVu).\nBitte ttf-liberation bzw. dejavu-fonts installieren.'
    [s7_mdl2]='Erzeuge Segoe-MDL2-Ersatzschrift (Titelleisten-Icons) ...'
    [s7_note]='(segmdl2.ttf ist optional - nur Titelleisten-Icons.)'

    [s8_title]='Schritt 8: Firewall'
    [s8_ufw]='Öffne UDP 3671 via ufw ...'
    [s8_firewalld]='Öffne UDP 3671 via firewalld ...'
    [s8_none]='Keine aktive Firewall (ufw/firewalld) erkannt.\n\nKNXnet/IP nutzt UDP-Port 3671. Ohne aktive Firewall ist nichts zu tun.\nFalls du eine andere Firewall nutzt, Port 3671/udp manuell freigeben.'

    [s9_dpi_title]='Schritt 9: DPI (optional)'
    [s9_dpi_menu]='Skalierung für hochauflösende Monitore.\n(Bei Standard-Auflösung: 96 belassen.)'
    [s9_dpi_96]='100%% (Standard)'
    [s9_dpi_120]='125%%'
    [s9_dpi_144]='150%%'
    [s9_dpi_192]='200%%'
    [s9_chk_ok]='WPF-Software-Modus aktiv (DisableHWAcceleration=1).'
    [s9_chk_fail]='DisableHWAcceleration nicht gesetzt - Hauptfenster bliebe schwarz.'

    [s10_title]='Schritt 10: Dongle'
    [s10_writing]='Schreibe udev-Regel (%s, GROUP=%s) ...'
    [s10_written]='udev-Regel geschrieben (GROUP=%s).\n\nBitte den KNX-USB-Dongle jetzt aus- und wieder einstecken.\n\nDanach PRÜFEN im Menü (Punkt 10 erneut) oder:\n  lsusb | grep -i 2a07'
    [s10_chk_ok]='Dongle erkannt (Vendor 2a07).'
    [s10_chk_fail]='Dongle nicht gefunden. Gesteckt? Aus/Einstecken nach Regel-Reload nötig.\nRegel-Datei: %s'
    [s10_present]='vorhanden'
    [s10_missing]='FEHLT'

    [s11_title]='Schritt 11: Start'
    [s11_notinstalled]='ETS6N.exe nicht gefunden. Erst Schritt 6 (Installation) durchführen.'
    [s11_confirm]='ETS6 wird jetzt gestartet.\n\nErwartung:\n- Splash-Screen (grün, KNX-Logo)\n- Hauptfenster mit Inhalt (nicht schwarz -> sonst Schritt 9 prüfen)\n- Mit Dongle: Lizenz erkannt. Cloud-Lizenz nach Login. Ohne: Demo.\n\nStarten?'
    [s11_starting]='Starte ETS6N.exe ... (dieses Terminal zeigt Wine-Ausgaben, Fenster kommt separat)'
    [s11_started]='ETS6 wurde gestartet (im Hintergrund).\n\nFalls kein Fenster erscheint oder es schwarz bleibt:\nLog prüfen (%s) und Schritt 9 kontrollieren.'

    [ra_title]='Alle Schritte'
    [ra_confirm]='Schritte 1 bis 10 werden nacheinander ausgeführt.\n\nDas umfasst längere, mehrminütige winetricks-Läufe (Schritt 4/5)\nund den interaktiven ETS-Installer (Schritt 6).\n\nFortfahren?'
    [ra_cont_title]='Weiter?'
    [ra_cn]='Schritt %s nicht sauber. Trotzdem weiter?'
    [ra_c2]='Wine zu alt/fehlt. Trotzdem weiter?'
    [ra_c3]='Prefix-Problem. Trotzdem weiter?'
    [ra_done_title]='Fertig'
    [ra_done]='Alle Schritte durchlaufen.\n\nETS jetzt via Menuepunkt 11 starten.'

    [cp_title]='Wine-Prefix ändern'
    [cp_prompt]='Pfad zum Wine-Prefix eingeben.\n\nAktuell: %s\n\n(~ und $HOME werden aufgelöst. Der Ordner wird bei\nSchritt 3 angelegt, falls er noch nicht existiert.)'
    [cp_notabs]='Bitte einen absoluten Pfad angeben (beginnend mit /).\n\nNicht übernommen: %s'
    [cp_exists]='Dieser Prefix existiert bereits (drive_c gefunden). Schritt 3 kann übersprungen werden.'
    [cp_new]='Dieser Prefix existiert noch NICHT. Schritt 3 legt ihn an.'
    [cp_applied]='Neuer Prefix übernommen:\n%s\n\n%s'

    [mm_title]='WineEts - Hauptmenü'
    [mm_header]='Distro: %s   |   Prefix: %s\n\nSchritt wählen (oder A für alle nacheinander):'
    [mm_A]='ALLE Schritte 1-10 nacheinander'
    [mm_1]='Systempakete installieren'
    [mm_2]='Wine-Version prüfen (>= 11.10)'
    [mm_3]='Wine-Prefix anlegen'
    [mm_4]='.NET 4.0 + 4.8 installieren'
    [mm_5]='VC++ Runtime + GDI+ + Windows-Schriften'
    [mm_6]='ETS 6.4.1 installieren'
    [mm_7]='Schriftarten'
    [mm_8]='Firewall (KNXnet/IP 3671)'
    [mm_9]='WPF-SW-Modus + Desktop'
    [mm_10]='USB-Lizenz-Dongle (udev)'
    [mm_11]='ETS starten'
    [mm_P]='Wine-Prefix ändern (aktuell: %s)'
    [mm_L]='Logdatei anzeigen'
    [mm_S]='Sprache / Language (aktuell: Deutsch)'
    [mm_Q]='Beenden'
    [mm_log_title]='Logdatei (Pfeiltasten scrollen, Tab -> OK -> Enter zum Schliessen)'
    [mm_log_title2]='Logdatei'
    [mm_log_empty]='Log ist noch leer:\n%s'

    [w_whiptail_missing]='whiptail fehlt (Paket: newt/libnewt). Bitte installieren.'
    [w_title]='WineEts - Willkommen'
    [w_body]='Dieses Skript richtet ETS 6.4.1 unter Wine ein.\n\nEs modifiziert KEINE ETS/KNX-Binaries. ETS wird unverändert\ninstalliert, nur die Wine-Umgebung wird vorbereitet.\n\nErkannte Distribution: %s\nWine-Prefix:           %s\nLogdatei:              %s\n\nBedienung: Pfeiltasten wählen, Tab wechselt zu den Buttons\n(OK / Abbrechen), Enter/Leertaste bestätigt.\n\nIm Menü die Schritte 1 bis 11 der Reihe nach abarbeiten.'
    [w_ok]='OK'
    [w_lang]='English'
    [w_bye]='Beendet. Log: %s'
)

declare -A T_en=(
    [backtitle]='WineEts  -  Set up ETS6 on Wine  v%s'
    [chk_title]='Step %s: CHECK'
    [result_ok]='OK - step completed successfully.\n\n%s'
    [result_fail]='ERROR - step did not complete (fully).\n\n%s\n\nDetails in the log:\n%s'
    [wi_running]='(running, details in the log: %s)'
    [wi_done]='done.'
    [chk_line_ok]='OK    %s'
    [chk_line_miss]='MISS  %s'

    [s1_title]='Step 1: Packages'
    [s1_pacman]='Installing system packages via pacman ...'
    [s1_apt]='Installing system packages via apt ...'
    [s1_dnf]='Installing system packages via dnf ...'
    [s1_zypper]='Installing system packages via zypper ...'
    [s1_unknown]='Distribution not recognised.\n\nPlease install manually:\nwine winetricks python3-fonttools cabextract unzip wget p7zip msitools'

    [s2_title]='Step 2: Wine version'
    [s2_notfound]='not found'
    [s2_ok]='Installed Wine: %s\n\nOK - version 11.10 or higher. Continue with step 3.'
    [s2_hint_debian]='Set up the WineHQ repo and install winehq-devel\n(NOT winehq-stable, that is 10.x and too old).\nSee the step 2 instructions.'
    [s2_hint_fedora]='Add the WineHQ repo, then: sudo dnf install winehq-devel'
    [s2_hint_opensuse]='Add the WineHQ repo, then: sudo zypper install winehq-devel'
    [s2_hint_other]='Install Wine 11.10+ from the WineHQ-devel repo.'
    [s2_body]='Installed Wine: %s\n\nETS6 needs Wine 11.10 or newer (development branch).\n\nRecommended update:\n%s\n\nThis step does NOT change system sources automatically, as that\nis distro- and version-dependent. Please update Wine and then\nre-check this step.'

    [s3_title]='Step 3: Wine prefix'
    [s3_creating]='Creating 64-bit Wine prefix at:\n%s'
    [s3_prefix]='Prefix: %s'

    [s4_title]='Step 4: .NET'
    [s4_confirm]='This installs .NET 4.0 and 4.8 via winetricks.\n\nThis takes SEVERAL MINUTES per runtime (download + installation\nof the real Microsoft installers). Please be patient, do not abort.\n\nContinue?'
    [s4_mono]='winetricks remove_mono (removes Wine-Mono) ...'
    [s4_dotnet40]='winetricks dotnet40 (several minutes) ...'
    [s4_dotnet48]='winetricks dotnet48 (several minutes) ...'
    [s4_chk_ok]='.NET 4.x present (clr.dll found).'
    [s4_chk_fail]='.NET missing - dotnet48 did not complete. Repeat step 4 if needed.'

    [s5_title_vc]='Step 5: VC++'
    [s5_title_fonts]='Step 5: Fonts'
    [s5_win10]='winetricks win10 (Windows version) ...'
    [s5_allfonts]='winetricks allfonts (standard Windows fonts, takes a while) ...'
    [s5_chk_ok]='vcruntime140.dll present.'
    [s5_chk_fail]='vcruntime140.dll missing - vcrun2022 did not complete.'

    [s6_title]='Step 6: ETS'
    [s6_reinstall]='ETS6N.exe already exists in the prefix.\n\nReinstall (run setup.exe again)?'
    [s6_found]='Found setup file:\n%s\n\nUse this one?'
    [s6_choose_title]='Step 6: Choose setup file'
    [s6_choose_menu]='Multiple ETS setups found:'
    [s6_path_title]='Step 6: Path to setup.exe'
    [s6_path_prompt]='Enter the full path to the ETS6 setup.exe:'
    [s6_notfound]='File not found:\n%s'
    [s6_installer]='The ETS installer will now start:\n%s\n\nPlease click through the graphical installer.\nWhen finished, return to this window (the script waits until the installer exits).'
    [s6_chk_ok]='ETS6N.exe installed.'
    [s6_chk_fail]='ETS6N.exe missing - installer did not complete or a different target path.'

    [s7_title]='Step 7: Fonts'
    [s7_nofont]='No replacement sans font found (Liberation/DejaVu).\nPlease install ttf-liberation or dejavu-fonts.'
    [s7_mdl2]='Generating Segoe MDL2 replacement font (title-bar icons) ...'
    [s7_note]='(segmdl2.ttf is optional - title-bar icons only.)'

    [s8_title]='Step 8: Firewall'
    [s8_ufw]='Opening UDP 3671 via ufw ...'
    [s8_firewalld]='Opening UDP 3671 via firewalld ...'
    [s8_none]='No active firewall (ufw/firewalld) detected.\n\nKNXnet/IP uses UDP port 3671. With no active firewall there is nothing to do.\nIf you use a different firewall, open port 3671/udp manually.'

    [s9_dpi_title]='Step 9: DPI (optional)'
    [s9_dpi_menu]='Scaling for high-resolution monitors.\n(For standard resolution: leave at 96.)'
    [s9_dpi_96]='100%% (default)'
    [s9_chk_ok]='WPF software mode active (DisableHWAcceleration=1).'
    [s9_chk_fail]='DisableHWAcceleration not set - the main window would stay black.'

    [s10_title]='Step 10: Dongle'
    [s10_writing]='Writing udev rule (%s, GROUP=%s) ...'
    [s10_written]='udev rule written (GROUP=%s).\n\nPlease unplug and replug the KNX USB dongle now.\n\nThen CHECK in the menu (item 10 again) or:\n  lsusb | grep -i 2a07'
    [s10_chk_ok]='Dongle detected (vendor 2a07).'
    [s10_chk_fail]='Dongle not found. Plugged in? Unplug/replug after rule reload required.\nRule file: %s'
    [s10_present]='present'
    [s10_missing]='MISSING'

    [s11_title]='Step 11: Launch'
    [s11_notinstalled]='ETS6N.exe not found. Run step 6 (installation) first.'
    [s11_confirm]='ETS6 will now start.\n\nExpected:\n- splash screen (green, KNX logo)\n- main window with content (not black -> otherwise check step 9)\n- with dongle: licence detected. Cloud licence after login. Without: demo.\n\nStart?'
    [s11_starting]='Starting ETS6N.exe ... (this terminal shows Wine output, the window opens separately)'
    [s11_started]='ETS6 has been started (in the background).\n\nIf no window appears or it stays black:\ncheck the log (%s) and review step 9.'

    [ra_title]='All steps'
    [ra_confirm]='Steps 1 to 10 run one after another.\n\nThis includes longer, multi-minute winetricks runs (steps 4/5)\nand the interactive ETS installer (step 6).\n\nContinue?'
    [ra_cont_title]='Continue?'
    [ra_cn]='Step %s not clean. Continue anyway?'
    [ra_c2]='Wine too old/missing. Continue anyway?'
    [ra_c3]='Prefix problem. Continue anyway?'
    [ra_done_title]='Done'
    [ra_done]='All steps completed.\n\nStart ETS now via menu item 11.'

    [cp_title]='Change Wine prefix'
    [cp_prompt]='Enter the path to the Wine prefix.\n\nCurrent: %s\n\n(~ and $HOME are expanded. The folder is created in\nstep 3 if it does not exist yet.)'
    [cp_notabs]='Please enter an absolute path (starting with /).\n\nNot applied: %s'
    [cp_exists]='This prefix already exists (drive_c found). Step 3 can be skipped.'
    [cp_new]='This prefix does NOT exist yet. Step 3 will create it.'
    [cp_applied]='New prefix applied:\n%s\n\n%s'

    [mm_title]='WineEts - Main menu'
    [mm_header]='Distro: %s   |   Prefix: %s\n\nChoose a step (or A for all in sequence):'
    [mm_A]='ALL steps 1-10 in sequence'
    [mm_1]='Install system packages'
    [mm_2]='Check Wine version (>= 11.10)'
    [mm_3]='Create Wine prefix'
    [mm_4]='Install .NET 4.0 + 4.8'
    [mm_5]='VC++ runtime + GDI+ + Windows fonts'
    [mm_6]='Install ETS 6.4.1'
    [mm_7]='Fonts'
    [mm_8]='Firewall (KNXnet/IP 3671)'
    [mm_9]='WPF SW mode + desktop'
    [mm_10]='USB licence dongle (udev)'
    [mm_11]='Start ETS'
    [mm_P]='Change Wine prefix (current: %s)'
    [mm_L]='Show log file'
    [mm_S]='Language / Sprache (current: English)'
    [mm_Q]='Quit'
    [mm_log_title]='Log file (arrow keys scroll, Tab -> OK -> Enter to close)'
    [mm_log_title2]='Log file'
    [mm_log_empty]='Log is still empty:\n%s'

    [w_whiptail_missing]='whiptail is missing (package: newt/libnewt). Please install it.'
    [w_title]='WineEts - Welcome'
    [w_body]='This script sets up ETS 6.4.1 on Wine.\n\nIt does NOT modify any ETS/KNX binaries. ETS is installed\nunchanged; only the Wine environment is prepared.\n\nDetected distribution: %s\nWine prefix:            %s\nLog file:               %s\n\nControls: arrow keys select, Tab switches to the buttons\n(OK / Cancel), Enter/Space confirms.\n\nWork through steps 1 to 11 in order in the menu.'
    [w_lang]='Deutsch'
    [w_bye]='Finished. Log: %s'
)

# t <key> [printf args...] -> print the translated string.
# The template may contain %s placeholders and \n; if the key is missing in the
# active language, it falls back to German (or, last resort, the key name).
t() {
    local key="$1"; shift
    local -n _tcat="T_${LANG_SEL}"
    local tmpl="${_tcat[$key]:-${T_de[$key]:-$key}}"
    # shellcheck disable=SC2059
    printf "$tmpl" "$@"
}

BACKTITLE="$(t backtitle "$VERSION")"

# ---------------------------------------------------------------------------
# Logging: everything to LOGFILE, important lines also into the TUI
# ---------------------------------------------------------------------------
log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >>"$LOGFILE"; }
run()  { log "RUN: $*"; "$@" >>"$LOGFILE" 2>&1; local rc=$?; log "RC=$rc"; return $rc; }

# ---------------------------------------------------------------------------
# Distro detection -> package manager
# ---------------------------------------------------------------------------
detect_distro() {
    local id id_like
    if [[ -r /etc/os-release ]]; then
        id=$(. /etc/os-release; echo "${ID:-}")
        id_like=$(. /etc/os-release; echo "${ID_LIKE:-}")
    fi
    case " $id $id_like " in
        *" arch "*|*" cachyos "*|*" endeavouros "*|*" manjaro "*) echo "arch" ;;
        *" debian "*|*" ubuntu "*|*" linuxmint "*|*" pop "*)      echo "debian" ;;
        *" fedora "*|*" nobara "*)                                echo "fedora" ;;
        *" opensuse "*|*" suse "*)                                echo "opensuse" ;;
        *)
            # Fallback: try the package managers directly
            if   command -v pacman  &>/dev/null; then echo "arch"
            elif command -v apt     &>/dev/null; then echo "debian"
            elif command -v dnf     &>/dev/null; then echo "fedora"
            elif command -v zypper  &>/dev/null; then echo "opensuse"
            else echo "unknown"; fi
            ;;
    esac
}
DISTRO="$(detect_distro)"

# ---------------------------------------------------------------------------
# TUI helpers
# ---------------------------------------------------------------------------
msg()   { whiptail --backtitle "$BACKTITLE" --title "$1" --msgbox "$2" "$WT_HEIGHT" "$WT_WIDTH"; }
yesno() { whiptail --backtitle "$BACKTITLE" --title "$1" --yesno   "$2" "$WT_HEIGHT" "$WT_WIDTH"; }

# Runs a command and shows an animated gauge while it runs, so it is clear the
# process is still working (important for long winetricks runs). The command
# runs in the background, the gauge animates until it finishes. Return value =
# exit code of the command.
# Usage: with_info "title" "description" cmd args...
with_info() {
    local title="$1" desc="$2"; shift 2

    # Start the command in the background, output to the log
    log "RUN: $*"
    "$@" >>"$LOGFILE" 2>&1 &
    local pid=$!

    # Animated gauge while the command runs.
    # The bar bounces back and forth + a small ASCII spinner runs below.
    local running; running="$(t wi_running "$LOGFILE")"
    local done_txt; done_txt="$(t wi_done)"
    {
        local pct=0 dir=1
        local -a spin=('|' '/' '-' '\')
        local i=0
        while kill -0 "$pid" 2>/dev/null; do
            printf 'XXX\n%d\n%s\n%s  [ %s ]\nXXX\n' \
                "$pct" "$desc" "$running" "${spin[i]}"
            i=$(( (i + 1) % 4 ))
            pct=$(( pct + dir * 5 ))
            (( pct >= 100 )) && { pct=100; dir=-1; }
            (( pct <= 0   )) && { pct=0;   dir=1;  }
            sleep 0.2
        done
        # Set to 100 at the end so the box closes cleanly
        printf 'XXX\n100\n%s\n%s\nXXX\n' "$desc" "$done_txt"
    } | whiptail --backtitle "$BACKTITLE" --title "$title" \
                 --gauge "$desc" 10 "$WT_WIDTH" 0

    wait "$pid"; local rc=$?
    log "RC=$rc"
    return $rc
}

# Shows the result of a CHECK block as an OK/ERROR box.
show_result() {
    local title="$1" ok="$2" detail="${3:-}"
    if [[ "$ok" == "0" ]]; then
        msg "$title" "$(t result_ok "$detail")"
    else
        msg "$title" "$(t result_fail "$detail" "$LOGFILE")"
    fi
}

# ===========================================================================
# STEP 1: System packages
# ===========================================================================
PKGS_ARCH=(wine winetricks python-fonttools cabextract unzip wget p7zip msitools gcc)
PKGS_DEBIAN=(wine64 wine32 winetricks python3-fonttools cabextract unzip wget p7zip-full msitools)
PKGS_FEDORA=(wine winetricks python3-fonttools cabextract unzip wget p7zip msitools)
PKGS_OPENSUSE=(wine winetricks python3-fonttools cabextract unzip wget glibc-32bit p7zip msitools gcc)

step01_packages() {
    local rc
    case "$DISTRO" in
        arch)     with_info "$(t s1_title)" "$(t s1_pacman)" \
                    sudo pacman -S --needed --noconfirm "${PKGS_ARCH[@]}"; rc=$? ;;
        debian)   run sudo dpkg --add-architecture i386
                  run sudo apt update
                  with_info "$(t s1_title)" "$(t s1_apt)" \
                    sudo apt install -y "${PKGS_DEBIAN[@]}"; rc=$? ;;
        fedora)   with_info "$(t s1_title)" "$(t s1_dnf)" \
                    sudo dnf install -y "${PKGS_FEDORA[@]}"; rc=$? ;;
        opensuse) with_info "$(t s1_title)" "$(t s1_zypper)" \
                    sudo zypper install -y "${PKGS_OPENSUSE[@]}"; rc=$? ;;
        *)        msg "$(t s1_title)" "$(t s1_unknown)"; return 1 ;;
    esac
    check01_packages
}

check01_packages() {
    local out="" ok=0 tool
    for tool in wine winetricks 7z msiextract cabextract; do
        if command -v "$tool" &>/dev/null; then out+="$(t chk_line_ok "$tool")\n"; else out+="$(t chk_line_miss "$tool")\n"; ok=1; fi
    done
    show_result "$(t chk_title 1)" "$ok" "$out"
    return $ok
}

# ===========================================================================
# STEP 2: Wine version (check only; updating is distro-specific + tricky)
# ===========================================================================
wine_version_ok() {
    # Success (0) if Wine >= 11.10
    local v major minor
    v=$(wine --version 2>/dev/null | sed -n 's/^wine-\([0-9]*\.[0-9]*\).*/\1/p')
    [[ -z "$v" ]] && return 2
    major="${v%%.*}"; minor="${v##*.}"
    if (( major > 11 )) || { (( major == 11 )) && (( minor >= 10 )); }; then return 0; fi
    return 1
}

step02_wine() {
    local v; v=$(wine --version 2>/dev/null || t s2_notfound)
    if wine_version_ok; then
        msg "$(t s2_title)" "$(t s2_ok "$v")"
        return 0
    fi
    # Too old or not found: show hints, do NOT rebuild the repo automatically. Depending on the distro this has always been tricky.
    local hint
    case "$DISTRO" in
        arch)     hint="$(t s2_hint_arch)" ;;
        debian)   hint="$(t s2_hint_debian)" ;;
        fedora)   hint="$(t s2_hint_fedora)" ;;
        opensuse) hint="$(t s2_hint_opensuse)" ;;
        *)        hint="$(t s2_hint_other)" ;;
    esac
    msg "$(t s2_title)" "$(t s2_body "$v" "$hint")"
    return 1
}

# ===========================================================================
# STEP 3: Wine prefix
# ===========================================================================
step03_prefix() {
    with_info "$(t s3_title)" "$(t s3_creating "$WINEPREFIX")" \
        wineboot --init
    run wineserver -w
    check03_prefix
}

check03_prefix() {
    local ok=1
    [[ -d "$WINEPREFIX/drive_c/windows/system32" ]] && ok=0
    show_result "$(t chk_title 3)" "$ok" "$(t s3_prefix "$WINEPREFIX")"
    return $ok
}

# ===========================================================================
# STEP 4: .NET Framework 4.0 + 4.8
# ===========================================================================
step04_dotnet() {
    yesno "$(t s4_title)" "$(t s4_confirm)" || return 1

    with_info "$(t s4_title)" "$(t s4_mono)" \
        winetricks -q remove_mono
    with_info "$(t s4_title)" "$(t s4_dotnet40)" \
        winetricks -q dotnet40
    with_info "$(t s4_title)" "$(t s4_dotnet48)" \
        winetricks -q dotnet48

    # mscoree override: ETS uses the real .NET instead of Wine-Mono
    run wine reg add 'HKCU\Software\Wine\DllOverrides' /v '*mscoree' /t REG_SZ /d 'native,builtin' /f
    run wine reg add 'HKCU\Software\Wine\DllOverrides' /v 'mscoree'  /t REG_SZ /d 'native,builtin' /f

    check04_dotnet
}

check04_dotnet() {
    local ok=1
    [[ -f "$WINEPREFIX/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/clr.dll" ]] && ok=0
    show_result "$(t chk_title 4)" "$ok" \
        "$([[ $ok == 0 ]] && t s4_chk_ok || t s4_chk_fail)"
    return $ok
}

# ===========================================================================
# STEP 5: Visual C++ runtime + GDI+ + Windows version
# ===========================================================================
VC_DLLS=(concrt140 msvcp140 msvcp140_1 msvcp140_2 msvcp140_atomic_wait
         msvcp140_codecvt_ids vcamp140 vccorlib140 vcomp140 vcruntime140 vcruntime140_1)

step05_vcrun() {
    with_info "$(t s5_title_vc)" "$(t s5_vcrun)" \
        winetricks -q vcrun2022
    with_info "$(t s5_title_vc)" "$(t s5_gdiplus)" \
        winetricks -q gdiplus
    with_info "$(t s5_title_vc)" "$(t s5_win10)" \
        winetricks -q win10

    # Standard Windows fonts (Arial, Tahoma, Consolas, Verdana, ...).
    # ETS / the installer expect these; without them you can get errors or empty dialogs.
    # Loads several fonts, takes a while.
    # Segoe UI and MDL2 are NOT included here (not freely distributable) -> step 7.
    with_info "$(t s5_title_fonts)" "$(t s5_allfonts)" \
        winetricks -q allfonts

    # Force the 11 VC runtime DLLs to native,builtin
    local dll
    for dll in "${VC_DLLS[@]}"; do
        run wine reg add 'HKCU\Software\Wine\DllOverrides' /v "*$dll" /t REG_SZ /d 'native,builtin' /f
    done

    check05_vcrun
}

check05_vcrun() {
    local ok=1
    [[ -f "$WINEPREFIX/drive_c/windows/system32/vcruntime140.dll" ]] && ok=0
    show_result "$(t chk_title 5)" "$ok" \
        "$([[ $ok == 0 ]] && t s5_chk_ok || t s5_chk_fail)"
    return $ok
}

# ===========================================================================
# STEP 6: Install ETS 6.4.1
# ===========================================================================
ETS_DIR_REL="drive_c/Program Files (x86)/ETS6"

# Look for setup.exe candidates (common locations), otherwise ask for the path.
find_setup_exe() {
    local hits=()
    local d f
    for d in "$HOME/Downloads" "$HOME/Schreibtisch" "$HOME/Desktop" "$PWD"; do
        [[ -d "$d" ]] || continue
        while IFS= read -r -d '' f; do hits+=("$f"); done \
            < <(find "$d" -maxdepth 1 -type f -iname '*ETS*6*.exe' -print0 2>/dev/null)
    done
    printf '%s\n' "${hits[@]}"
}

step06_ets() {
    # Already installed?
    if [[ -f "$WINEPREFIX/$ETS_DIR_REL/ETS6N.exe" ]]; then
        yesno "$(t s6_title)" "$(t s6_reinstall)" || { check06_ets; return; }
    fi

    # Find or ask for setup.exe
    local setup="" candidates
    mapfile -t candidates < <(find_setup_exe)
    if (( ${#candidates[@]} == 1 )); then
        yesno "$(t s6_title)" "$(t s6_found "${candidates[0]}")" \
            && setup="${candidates[0]}"
    elif (( ${#candidates[@]} > 1 )); then
        local menu=() i=0
        for c in "${candidates[@]}"; do menu+=("$((++i))" "$c"); done
        local sel
        sel=$(whiptail --backtitle "$BACKTITLE" --title "$(t s6_choose_title)" \
              --menu "$(t s6_choose_menu)" "$WT_HEIGHT" "$WT_WIDTH" 6 "${menu[@]}" 3>&1 1>&2 2>&3) \
            && setup="${candidates[$((sel-1))]}"
    fi
    if [[ -z "$setup" ]]; then
        setup=$(whiptail --backtitle "$BACKTITLE" --title "$(t s6_path_title)" \
                --inputbox "$(t s6_path_prompt)" \
                "$WT_HEIGHT" "$WT_WIDTH" "$HOME/Downloads/" 3>&1 1>&2 2>&3) || return 1
    fi
    if [[ ! -f "$setup" ]]; then
        msg "$(t s6_title)" "$(t s6_notfound "$setup")"
        return 1
    fi

    msg "$(t s6_title)" "$(t s6_installer "$setup")"
    run wine "$setup"

    # Stage 2: ETS6N.exe possibly elsewhere? Quick visual check.
    apply_exe_config
    check06_ets
}

# Add two .NET switches to .exe.config (external XML, no binary modification).
apply_exe_config() {
    local etsdir="$WINEPREFIX/$ETS_DIR_REL" exe cfg
    local block='    <legacyCorruptedStateExceptionsPolicy enabled="true" />\n    <AppContextSwitchOverrides value="Switch.System.Windows.Controls.Grid.StarDefinitionsCanExceedAvailableSpace=true" />'
    for exe in ETS6N.exe ETS6C.exe; do
        cfg="$etsdir/$exe.config"
        [[ -f "$cfg" ]] || continue
        grep -q "legacyCorruptedStateExceptionsPolicy" "$cfg" && continue
        # insert after the first <runtime>
        if grep -q "<runtime>" "$cfg"; then
            cp "$cfg" "$cfg.bak-ets6setup" 2>/dev/null
            sed -i "s|<runtime>|<runtime>\n$block|" "$cfg"
            log "exe.config extended: $cfg"
        fi
    done
}

check06_ets() {
    local ok=1
    [[ -f "$WINEPREFIX/$ETS_DIR_REL/ETS6N.exe" ]] && ok=0
    show_result "$(t chk_title 6)" "$ok" \
        "$([[ $ok == 0 ]] && t s6_chk_ok || t s6_chk_fail)"
    return $ok
}

# ===========================================================================
# STEP 7: Fonts
# ===========================================================================
# Finds a suitable replacement font file for Segoe UI (sans).
find_sans_font() {
    local c
    for c in \
        /usr/share/fonts/liberation/LiberationSans-Regular.ttf \
        /usr/share/fonts/liberation-fonts/LiberationSans-Regular.ttf \
        /usr/share/fonts/TTF/LiberationSans-Regular.ttf \
        /usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf \
        /usr/share/fonts/TTF/DejaVuSans.ttf \
        /usr/share/fonts/dejavu/DejaVuSans.ttf \
        /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf; do
        [[ -f "$c" ]] && { echo "$c"; return 0; }
    done
    # Fallback: any DejaVuSans/Liberation via find
    find /usr/share/fonts -iname 'LiberationSans-Regular.ttf' -o -iname 'DejaVuSans.ttf' 2>/dev/null | head -1
}

step07_fonts() {
    local fontsdir="$WINEPREFIX/drive_c/windows/Fonts"
    mkdir -p "$fontsdir"

    # --- Segoe UI ---
    local src; src="$(find_sans_font)"
    if [[ -z "$src" ]]; then
        msg "$(t s7_title)" "$(t s7_nofont)"
        return 1
    fi
    run cp "$src" "$fontsdir/segoeui.ttf"
    run wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes' /v 'Segoe UI' /t REG_SZ /d 'Segoe UI' /f
    run wine reg add 'HKCU\Software\Wine\Fonts\Replacements' /v 'Segoe UI' /t REG_SZ /d 'Liberation Sans' /f

    # --- Consolas ---
    run wine reg add 'HKCU\Software\Wine\Fonts\Replacements' /v 'Consolas' /t REG_SZ /d 'Liberation Mono' /f

    # --- Segoe MDL2 Assets (procedural via make-mdl2.py) ---
    if [[ -f "$MDL2_SCRIPT" ]] && command -v python3 &>/dev/null; then
        with_info "$(t s7_title)" "$(t s7_mdl2)" \
            python3 "$MDL2_SCRIPT" "$fontsdir/segmdl2.ttf"
        run wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' /v 'Segoe MDL2 Assets (TrueType)' /t REG_SZ /d 'segmdl2.ttf' /f
    else
        log "make-mdl2.py or python3 missing - MDL2 skipped"
    fi

    check07_fonts
}

check07_fonts() {
    local out="" ok=0 f
    for f in segoeui.ttf segmdl2.ttf; do
        if [[ -f "$WINEPREFIX/drive_c/windows/Fonts/$f" ]]; then out+="$(t chk_line_ok "$f")\n"; else out+="$(t chk_line_miss "$f")\n"; [[ "$f" == segoeui.ttf ]] && ok=1; fi
    done
    show_result "$(t chk_title 7)" "$ok" "$out\n$(t s7_note)"
    return $ok
}

# ===========================================================================
# STEP 8: Firewall (KNXnet/IP UDP 3671)
# ===========================================================================
step08_firewall() {
    if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -qi active; then
        with_info "$(t s8_title)" "$(t s8_ufw)" \
            sudo ufw allow 3671/udp
    elif command -v firewall-cmd &>/dev/null && sudo firewall-cmd --state 2>/dev/null | grep -qi running; then
        with_info "$(t s8_title)" "$(t s8_firewalld)" \
            sudo firewall-cmd --permanent --add-port=3671/udp
        run sudo firewall-cmd --reload
    else
        msg "$(t s8_title)" "$(t s8_none)"
    fi
    return 0
}

# ===========================================================================
# STEP 9: WPF software mode + desktop integration
# ===========================================================================
step09_wpf() {
    # IMPORTANT: without DisableHWAcceleration the main window stays black.
    run wine reg add 'HKCU\SOFTWARE\Microsoft\Avalon.Graphics' /v DisableHWAcceleration /t REG_DWORD /d 1 /f

    # WebView2 stubs (only presence required)
    local guid='{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' ver='109.0.1518.140'
    run wine reg add "HKCU\\Software\\Microsoft\\EdgeUpdate\\ClientState\\$guid" /v pv /t REG_SZ /d "$ver" /f
    run wine reg add "HKCU\\Software\\Microsoft\\EdgeUpdate\\Clients\\$guid"     /v pv /t REG_SZ /d "$ver" /f
    run wine reg add 'HKCU\Software\Wine\AppDefaults\msedgewebview2.exe' /v Version /t REG_SZ /d 'win7' /f

    # DPI optional prompt
    local dpi
    dpi=$(whiptail --backtitle "$BACKTITLE" --title "$(t s9_dpi_title)" \
          --menu "$(t s9_dpi_menu)" \
          "$WT_HEIGHT" "$WT_WIDTH" 5 \
          "96"  "$(t s9_dpi_96)" \
          "120" "$(t s9_dpi_120)" \
          "144" "$(t s9_dpi_144)" \
          "192" "$(t s9_dpi_192)" \
          3>&1 1>&2 2>&3) || dpi="96"
    run wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "$dpi" /f

    check09_wpf
}

check09_wpf() {
    local ok=1
    wine reg query 'HKCU\SOFTWARE\Microsoft\Avalon.Graphics' /v DisableHWAcceleration 2>/dev/null | grep -q '0x1' && ok=0
    show_result "$(t chk_title 9)" "$ok" \
        "$([[ $ok == 0 ]] && t s9_chk_ok || t s9_chk_fail)"
    return $ok
}

# ===========================================================================
# STEP 10: USB licence dongle (udev rule)
# ===========================================================================
UDEV_RULE="/etc/udev/rules.d/90-knx-usb.rules"
step10_udev() {
    local grp="plugdev"
    getent group plugdev &>/dev/null || grp="users"
    local rule="SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"2a07\", ATTRS{idProduct}==\"0102\", MODE=\"0660\", GROUP=\"$grp\", TAG+=\"uaccess\""

    with_info "$(t s10_title)" "$(t s10_writing "$UDEV_RULE" "$grp")" \
        bash -c "echo '$rule' | sudo tee '$UDEV_RULE' >/dev/null"
    run sudo udevadm control --reload-rules
    run sudo udevadm trigger

    msg "$(t s10_title)" "$(t s10_written "$grp")"
    check10_udev
}

check10_udev() {
    local ok=1 detail
    if lsusb 2>/dev/null | grep -qi '2a07'; then ok=0; detail="$(t s10_chk_ok)"
    else detail="$(t s10_chk_fail "$([[ -f $UDEV_RULE ]] && t s10_present || t s10_missing)")"; fi
    show_result "$(t chk_title 10)" "$ok" "$detail"
    return $ok
}

# ===========================================================================
# STEP 11: Start ETS
# ===========================================================================
step11_launch() {
    if [[ ! -f "$WINEPREFIX/$ETS_DIR_REL/ETS6N.exe" ]]; then
        msg "$(t s11_title)" "$(t s11_notinstalled)"
        return 1
    fi
    yesno "$(t s11_title)" "$(t s11_confirm)" || return 0

    clear
    echo "$(t s11_starting)"
    WINEPREFIX="$WINEPREFIX" wine "C:\\Program Files (x86)\\ETS6\\ETS6N.exe" >>"$LOGFILE" 2>&1 &
    disown
    sleep 3
    msg "$(t s11_title)" "$(t s11_started "$LOGFILE")"
}

# ===========================================================================
# All steps in sequence
# ===========================================================================
run_all() {
    yesno "$(t ra_title)" "$(t ra_confirm)" || return
    step01_packages || { yesno "$(t ra_cont_title)" "$(t ra_cn 1)" || return; }
    step02_wine     || { yesno "$(t ra_cont_title)" "$(t ra_c2)"   || return; }
    step03_prefix   || { yesno "$(t ra_cont_title)" "$(t ra_c3)"   || return; }
    step04_dotnet   || { yesno "$(t ra_cont_title)" "$(t ra_cn 4)" || return; }
    step05_vcrun    || { yesno "$(t ra_cont_title)" "$(t ra_cn 5)" || return; }
    step06_ets      || { yesno "$(t ra_cont_title)" "$(t ra_cn 6)" || return; }
    step07_fonts    || { yesno "$(t ra_cont_title)" "$(t ra_cn 7)" || return; }
    step08_firewall
    step09_wpf      || { yesno "$(t ra_cont_title)" "$(t ra_cn 9)" || return; }
    step10_udev
    msg "$(t ra_done_title)" "$(t ra_done)"
}

# ===========================================================================
# Change Wine prefix (at runtime)
# ===========================================================================
change_prefix() {
    local new
    new=$(whiptail --backtitle "$BACKTITLE" --title "$(t cp_title)" \
        --inputbox "$(t cp_prompt "$WINEPREFIX")" \
        "$WT_HEIGHT" "$WT_WIDTH" "$WINEPREFIX" 3>&1 1>&2 2>&3) || return 0

    # Empty -> cancel
    [[ -z "$new" ]] && return 0

    # Expand ~ and $HOME/variables
    new="${new/#\~/$HOME}"
    eval "new=\"$new\""

    # Must be an absolute path
    if [[ "$new" != /* ]]; then
        msg "$(t cp_title)" "$(t cp_notabs "$new")"
        return 1
    fi

    WINEPREFIX="$new"
    export WINEPREFIX
    log "WINEPREFIX changed to: $WINEPREFIX"

    local status
    if [[ -d "$WINEPREFIX/drive_c/windows/system32" ]]; then
        status="$(t cp_exists)"
    else
        status="$(t cp_new)"
    fi
    msg "$(t cp_title)" "$(t cp_applied "$WINEPREFIX" "$status")"
}

# ===========================================================================
# Main menu
# ===========================================================================
main_menu() {
    local choice
    while true; do
        choice=$(whiptail --backtitle "$BACKTITLE" \
            --title "$(t mm_title)" \
            --menu "$(t mm_header "$DISTRO" "$WINEPREFIX")" \
            "$WT_HEIGHT" "$WT_WIDTH" "$WT_MENU_HEIGHT" \
            "S"  "$(t mm_S)" \
            "A"  "$(t mm_A)" \
            "1"  "$(t mm_1)" \
            "2"  "$(t mm_2)" \
            "3"  "$(t mm_3)" \
            "4"  "$(t mm_4)" \
            "5"  "$(t mm_5)" \
            "6"  "$(t mm_6)" \
            "7"  "$(t mm_7)" \
            "8"  "$(t mm_8)" \
            "9"  "$(t mm_9)" \
            "10" "$(t mm_10)" \
            "11" "$(t mm_11)" \
            "P"  "$(t mm_P "$WINEPREFIX")" \
            "L"  "$(t mm_L)" \
            "Q"  "$(t mm_Q)" \
            3>&1 1>&2 2>&3) || break

        case "$choice" in
            A)  run_all ;;
            P)  change_prefix ;;
            1)  step01_packages ;;
            2)  step02_wine ;;
            3)  step03_prefix ;;
            4)  step04_dotnet ;;
            5)  step05_vcrun ;;
            6)  step06_ets ;;
            7)  step07_fonts ;;
            8)  step08_firewall ;;
            9)  step09_wpf ;;
            10) step10_udev ;;
            11) step11_launch ;;
            L)  if [[ -s "$LOGFILE" ]]; then
                    whiptail --backtitle "$BACKTITLE" --title "$(t mm_log_title)" \
                        --scrolltext --textbox "$LOGFILE" "$WT_HEIGHT" "$WT_WIDTH"
                else
                    msg "$(t mm_log_title2)" "$(t mm_log_empty "$LOGFILE")"
                fi ;;
            S)  # Switch language and rebuild the backtitle
                if [[ "$LANG_SEL" == de ]]; then LANG_SEL=en; else LANG_SEL=de; fi
                BACKTITLE="$(t backtitle "$VERSION")" ;;
            Q)  break ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
main() {
    command -v whiptail &>/dev/null || { echo "$(t w_whiptail_missing)"; exit 1; }
    log "WineEts (wineets.sh) v$VERSION started. Distro=$DISTRO Prefix=$WINEPREFIX Lang=$LANG_SEL"
    # Welcome screen with a language toggle (OK proceeds, the other button switches DE<->EN)
    while true; do
        whiptail --backtitle "$BACKTITLE" --title "$(t w_title)" \
            --yes-button "$(t w_ok)" --no-button "$(t w_lang)" \
            --yesno "$(t w_body "$DISTRO" "$WINEPREFIX" "$LOGFILE")" \
            "$WT_HEIGHT" "$WT_WIDTH"
        case $? in
            0) break ;;   # OK -> continue to the menu
            1) if [[ "$LANG_SEL" == de ]]; then LANG_SEL=en; else LANG_SEL=de; fi
               BACKTITLE="$(t backtitle "$VERSION")" ;;
            *) break ;;   # ESC etc. -> just continue
        esac
    done
    main_menu
    clear
    echo "$(t w_bye "$LOGFILE")"
}

main "$@"
