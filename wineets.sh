#!/usr/bin/env bash
#
# wineets.sh - WineEts: ETS 6.4.1 unter Wine einrichten (TUI)
#
# Automatisiert das Einrichten einer WINE Umgebung zur Installation der ETS 6.4.1.
# Die ETS wird unverändert installiert und entspricht 1:1 einer Windows-Installtion.
#
# Bedienung: whiptail-Menü. Schritte einzeln oder am Stück ausführbar, jeder mit eigenem PRÜFEN-Block.
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Robert Gerigk
#
# Dieses Programm ist Freie Software unter der GNU GPL v3 oder neuer.
# Der vollständige Lizenztext steht in der Datei LICENSE.
#
# GEPRIESEN SEI DER OMNISSIAH!
#
#
set -uo pipefail

# ---------------------------------------------------------------------------
# Globale Konfiguration
# ---------------------------------------------------------------------------
VERSION="0.1.0"
WINEPREFIX_DEFAULT="$HOME/.wine-ets6"
WINEPREFIX="${WINEPREFIX:-$WINEPREFIX_DEFAULT}"
export WINEPREFIX
export WINEARCH=win64

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
MDL2_SCRIPT="$SCRIPT_DIR/make-mdl2.py"
LOGFILE="${TMPDIR:-/tmp}/wineets-$(date +%Y%m%d-%H%M%S).log"

# whiptail-Größe
WT_HEIGHT=20
WT_WIDTH=76
WT_MENU_HEIGHT=12
BACKTITLE="WineEts  -  ETS6 unter Wine einrichten  v$VERSION"

# ---------------------------------------------------------------------------
# Logging: alles nach LOGFILE, wichtige Zeilen zusätzlich in die TUI
# ---------------------------------------------------------------------------
log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >>"$LOGFILE"; }
run()  { log "RUN: $*"; "$@" >>"$LOGFILE" 2>&1; local rc=$?; log "RC=$rc"; return $rc; }

# ---------------------------------------------------------------------------
# Distro-Erkennung -> Paketmanager
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
            # Fallback: Paketmanager direkt probieren
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
# TUI-Helfer
# ---------------------------------------------------------------------------
msg()   { whiptail --backtitle "$BACKTITLE" --title "$1" --msgbox "$2" "$WT_HEIGHT" "$WT_WIDTH"; }
yesno() { whiptail --backtitle "$BACKTITLE" --title "$1" --yesno   "$2" "$WT_HEIGHT" "$WT_WIDTH"; }

# Führt einen Befehl aus und zeigt währenddessen einen animierten Gauge,
# damit klar ist, dass der Prozess noch läuft (wichtig bei langen
# winetricks-Laeufen). Der Befehl läuft im Hintergrund, der Gauge
# animiert bis er fertig ist. Rückgabewert = Exit-Code des Befehls.
# Nutzung: with_info "Titel" "Beschreibung" cmd args...
with_info() {
    local title="$1" desc="$2"; shift 2

    # Befehl im Hintergrund starten, Ausgabe ins Log
    log "RUN: $*"
    "$@" >>"$LOGFILE" 2>&1 &
    local pid=$!

    # Animierter Gauge, solange der Befehl läuft.
    # Der Balken pendelt hin und her + unten läuft ein kleiner ASCII-Spinner.
    {
        local pct=0 dir=1
        local -a spin=('|' '/' '-' '\')
        local i=0
        while kill -0 "$pid" 2>/dev/null; do
            printf 'XXX\n%d\n%s\n%s  [ %s ]\nXXX\n' \
                "$pct" "$desc" "(läuft, Details im Log: $LOGFILE)" "${spin[i]}"
            i=$(( (i + 1) % 4 ))
            pct=$(( pct + dir * 5 ))
            (( pct >= 100 )) && { pct=100; dir=-1; }
            (( pct <= 0   )) && { pct=0;   dir=1;  }
            sleep 0.2
        done
        # Am Ende auf 100 setzen, damit die Box sauber schliesst
        printf 'XXX\n100\n%s\nfertig.\nXXX\n' "$desc"
    } | whiptail --backtitle "$BACKTITLE" --title "$title" \
                 --gauge "$desc" 10 "$WT_WIDTH" 0

    wait "$pid"; local rc=$?
    log "RC=$rc"
    return $rc
}

# Zeigt das Ergebnis eines PRÜFEN-Blocks als OK/FEHLER-Box.
show_result() {
    local title="$1" ok="$2" detail="${3:-}"
    if [[ "$ok" == "0" ]]; then
        msg "$title" "OK - Schritt erfolgreich.\n\n${detail}"
    else
        msg "$title" "FEHLER - Schritt nicht (vollständig) erfolgreich.\n\n${detail}\n\nDetails im Log:\n$LOGFILE"
    fi
}

# ===========================================================================
# SCHRITT 1: Systempakete
# ===========================================================================
PKGS_ARCH=(wine winetricks python-fonttools cabextract unzip wget p7zip msitools gcc)
PKGS_DEBIAN=(wine64 wine32 winetricks python3-fonttools cabextract unzip wget p7zip-full msitools)
PKGS_FEDORA=(wine winetricks python3-fonttools cabextract unzip wget p7zip msitools)
PKGS_OPENSUSE=(wine winetricks python3-fonttools cabextract unzip wget glibc-32bit p7zip msitools gcc)

step01_packages() {
    local rc
    case "$DISTRO" in
        arch)     with_info "Schritt 1: Pakete" "Installiere Systempakete via pacman ..." \
                    sudo pacman -S --needed --noconfirm "${PKGS_ARCH[@]}"; rc=$? ;;
        debian)   run sudo dpkg --add-architecture i386
                  run sudo apt update
                  with_info "Schritt 1: Pakete" "Installiere Systempakete via apt ..." \
                    sudo apt install -y "${PKGS_DEBIAN[@]}"; rc=$? ;;
        fedora)   with_info "Schritt 1: Pakete" "Installiere Systempakete via dnf ..." \
                    sudo dnf install -y "${PKGS_FEDORA[@]}"; rc=$? ;;
        opensuse) with_info "Schritt 1: Pakete" "Installiere Systempakete via zypper ..." \
                    sudo zypper install -y "${PKGS_OPENSUSE[@]}"; rc=$? ;;
        *)        msg "Schritt 1: Pakete" "Distribution nicht erkannt.\n\nBitte manuell installieren:\nwine winetricks python3-fonttools cabextract unzip wget p7zip msitools"; return 1 ;;
    esac
    check01_packages
}

check01_packages() {
    local out="" ok=0 t
    for t in wine winetricks 7z msiextract cabextract; do
        if command -v "$t" &>/dev/null; then out+="OK    $t\n"; else out+="FEHLT $t\n"; ok=1; fi
    done
    show_result "Schritt 1: PRÜFEN" "$ok" "$out"
    return $ok
}

# ===========================================================================
# SCHRITT 2: Wine-Version (nur prüfen; Update ist distro-spezifisch + heikel)
# ===========================================================================
wine_version_ok() {
    # Erfolg (0), wenn Wine >= 11.10
    local v major minor
    v=$(wine --version 2>/dev/null | sed -n 's/^wine-\([0-9]*\.[0-9]*\).*/\1/p')
    [[ -z "$v" ]] && return 2
    major="${v%%.*}"; minor="${v##*.}"
    if (( major > 11 )) || { (( major == 11 )) && (( minor >= 10 )); }; then return 0; fi
    return 1
}

step02_wine() {
    local v; v=$(wine --version 2>/dev/null || echo "nicht gefunden")
    if wine_version_ok; then
        msg "Schritt 2: Wine-Version" "Installiertes Wine: $v\n\nOK - Version 11.10 oder höher. Weiter mit Schritt 3."
        return 0
    fi
    # Zu alt oder nicht gefunden: Hinweise zeigen, NICHT automatisch das Repo umbauen. Je nach Distro war das in der Vergangenheit immer schwierig. 
    local hint
    case "$DISTRO" in
        arch)     hint="sudo pacman -Syu wine" ;;
        debian)   hint="WineHQ-Repo einrichten und winehq-devel installieren\n(NICHT winehq-stable, das ist 10.x und zu alt).\nSiehe Anleitung Schritt 2." ;;
        fedora)   hint="WineHQ-Repo hinzufügen, dann: sudo dnf install winehq-devel" ;;
        opensuse) hint="WineHQ-Repo hinzufügen, dann: sudo zypper install winehq-devel" ;;
        *)        hint="Wine 11.10+ aus dem WineHQ-devel-Repo installieren." ;;
    esac
    msg "Schritt 2: Wine-Version" \
"Installiertes Wine: $v

ETS6 braucht Wine 11.10 oder neuer (Development-Branch).

Empfohlenes Update:
$hint

Dieser Schritt ändert Systemquellen NICHT automatisch, da das
distro- und versionsabhängig ist. Bitte Wine aktualisieren und
dann diesen Schritt erneut prüfen."
    return 1
}

# ===========================================================================
# SCHRITT 3: Wine-Prefix
# ===========================================================================
step03_prefix() {
    with_info "Schritt 3: Wine-Prefix" "Erzeuge 64-bit Wine-Prefix unter:\n$WINEPREFIX" \
        wineboot --init
    run wineserver -w
    check03_prefix
}

check03_prefix() {
    local ok=1
    [[ -d "$WINEPREFIX/drive_c/windows/system32" ]] && ok=0
    show_result "Schritt 3: PRÜFEN" "$ok" "Prefix: $WINEPREFIX"
    return $ok
}

# ===========================================================================
# SCHRITT 4: .NET Framework 4.0 + 4.8
# ===========================================================================
step04_dotnet() {
    yesno "Schritt 4: .NET" \
"Jetzt werden .NET 4.0 und 4.8 via winetricks installiert.

Das dauert MEHRERE MINUTEN je Runtime (Download + Installation
der echten Microsoft-Installer). Bitte Geduld, nicht abbrechen.

Fortfahren?" || return 1

    with_info "Schritt 4: .NET" "winetricks remove_mono (entfernt Wine-Mono) ..." \
        winetricks -q remove_mono
    with_info "Schritt 4: .NET" "winetricks dotnet40 (mehrere Minuten) ..." \
        winetricks -q dotnet40
    with_info "Schritt 4: .NET" "winetricks dotnet48 (mehrere Minuten) ..." \
        winetricks -q dotnet48

    # mscoree-Override: ETS nutzt das echte .NET statt Wine-Mono
    run wine reg add 'HKCU\Software\Wine\DllOverrides' /v '*mscoree' /t REG_SZ /d 'native,builtin' /f
    run wine reg add 'HKCU\Software\Wine\DllOverrides' /v 'mscoree'  /t REG_SZ /d 'native,builtin' /f

    check04_dotnet
}

check04_dotnet() {
    local ok=1
    [[ -f "$WINEPREFIX/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/clr.dll" ]] && ok=0
    show_result "Schritt 4: PRÜFEN" "$ok" \
        "$([[ $ok == 0 ]] && echo '.NET 4.x vorhanden (clr.dll gefunden).' || echo '.NET fehlt - dotnet48 nicht durchgelaufen. Ggf. Schritt 4 wiederholen.')"
    return $ok
}

# ===========================================================================
# SCHRITT 5: Visual C++ Runtime + GDI+ + Windows-Version
# ===========================================================================
VC_DLLS=(concrt140 msvcp140 msvcp140_1 msvcp140_2 msvcp140_atomic_wait
         msvcp140_codecvt_ids vcamp140 vccorlib140 vcomp140 vcruntime140 vcruntime140_1)

step05_vcrun() {
    with_info "Schritt 5: VC++" "winetricks vcrun2022 ..." \
        winetricks -q vcrun2022
    with_info "Schritt 5: VC++" "winetricks gdiplus ..." \
        winetricks -q gdiplus
    with_info "Schritt 5: VC++" "winetricks win10 (Windows-Version) ..." \
        winetricks -q win10

    # Windows-Standardschriften (Arial, Tahoma, Consolas, Verdana, ...).
    # ETS bzw. der Installer erwarten diese; ohne sie kann es zu Fehlern oder leeren Dialogen kommen. 
    # Lädt mehrere Schriften, dauert etwas.
    # Segoe UI und MDL2 sind hier NICHT dabei (nicht frei verteilbar) -> Schritt 7.
    with_info "Schritt 5: Schriften" "winetricks allfonts (Windows-Standardschriften, dauert etwas) ..." \
        winetricks -q allfonts

    # Die 11 VC-Runtime-DLLs auf native,builtin zwingen
    local dll
    for dll in "${VC_DLLS[@]}"; do
        run wine reg add 'HKCU\Software\Wine\DllOverrides' /v "*$dll" /t REG_SZ /d 'native,builtin' /f
    done

    check05_vcrun
}

check05_vcrun() {
    local ok=1
    [[ -f "$WINEPREFIX/drive_c/windows/system32/vcruntime140.dll" ]] && ok=0
    show_result "Schritt 5: PRÜFEN" "$ok" \
        "$([[ $ok == 0 ]] && echo 'vcruntime140.dll vorhanden.' || echo 'vcruntime140.dll fehlt - vcrun2022 nicht durchgelaufen.')"
    return $ok
}

# ===========================================================================
# SCHRITT 6: ETS 6.4.1 installieren
# ===========================================================================
ETS_DIR_REL="drive_c/Program Files (x86)/ETS6"

# Kandidaten für die setup.exe suchen (häufige Orte), sonst Pfad abfragen.
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
    # Schon installiert?
    if [[ -f "$WINEPREFIX/$ETS_DIR_REL/ETS6N.exe" ]]; then
        yesno "Schritt 6: ETS" "ETS6N.exe ist bereits im Prefix vorhanden.\n\nNeu installieren (setup.exe erneut ausführen)?" || { check06_ets; return; }
    fi

    # setup.exe finden oder abfragen
    local setup="" candidates
    mapfile -t candidates < <(find_setup_exe)
    if (( ${#candidates[@]} == 1 )); then
        yesno "Schritt 6: ETS" "Gefundene Setup-Datei:\n${candidates[0]}\n\nDiese verwenden?" \
            && setup="${candidates[0]}"
    elif (( ${#candidates[@]} > 1 )); then
        local menu=() i=0
        for c in "${candidates[@]}"; do menu+=("$((++i))" "$c"); done
        local sel
        sel=$(whiptail --backtitle "$BACKTITLE" --title "Schritt 6: Setup-Datei wählen" \
              --menu "Mehrere ETS-Setups gefunden:" "$WT_HEIGHT" "$WT_WIDTH" 6 "${menu[@]}" 3>&1 1>&2 2>&3) \
            && setup="${candidates[$((sel-1))]}"
    fi
    if [[ -z "$setup" ]]; then
        setup=$(whiptail --backtitle "$BACKTITLE" --title "Schritt 6: Pfad zur setup.exe" \
                --inputbox "Vollständigen Pfad zur ETS6-Setup.exe eingeben:" \
                "$WT_HEIGHT" "$WT_WIDTH" "$HOME/Downloads/" 3>&1 1>&2 2>&3) || return 1
    fi
    if [[ ! -f "$setup" ]]; then
        msg "Schritt 6: ETS" "Datei nicht gefunden:\n$setup"
        return 1
    fi

    msg "Schritt 6: ETS" \
"Der ETS-Installer wird jetzt gestartet:\n$setup\n\nBitte durch den grafischen Installer klicken.\nNach Abschluss dieses Fenster wieder aufsuchen (das Skript wartet, bis der Installer beendet ist)."
    run wine "$setup"

    # Stage-2: ETS6N.exe evtl. an anderer Stelle? Kurzer Sichtcheck.
    apply_exe_config
    check06_ets
}

# .exe.config um zwei .NET-Schalter ergänzen (externe XML, kein Binary-Eingriff).
apply_exe_config() {
    local etsdir="$WINEPREFIX/$ETS_DIR_REL" exe cfg
    local block='    <legacyCorruptedStateExceptionsPolicy enabled="true" />\n    <AppContextSwitchOverrides value="Switch.System.Windows.Controls.Grid.StarDefinitionsCanExceedAvailableSpace=true" />'
    for exe in ETS6N.exe ETS6C.exe; do
        cfg="$etsdir/$exe.config"
        [[ -f "$cfg" ]] || continue
        grep -q "legacyCorruptedStateExceptionsPolicy" "$cfg" && continue
        # nach dem ersten <runtime> einfuegen
        if grep -q "<runtime>" "$cfg"; then
            cp "$cfg" "$cfg.bak-ets6setup" 2>/dev/null
            sed -i "s|<runtime>|<runtime>\n$block|" "$cfg"
            log "exe.config ergänzt: $cfg"
        fi
    done
}

check06_ets() {
    local ok=1
    [[ -f "$WINEPREFIX/$ETS_DIR_REL/ETS6N.exe" ]] && ok=0
    show_result "Schritt 6: PRÜFEN" "$ok" \
        "$([[ $ok == 0 ]] && echo 'ETS6N.exe installiert.' || echo 'ETS6N.exe fehlt - Installer nicht durchgelaufen oder anderer Zielpfad.')"
    return $ok
}

# ===========================================================================
# SCHRITT 7: Schriftarten
# ===========================================================================
# Findet eine passende Ersatz-Schrift-Datei für Segoe UI (Sans).
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
    # Fallback: irgendeine DejaVuSans/Liberation per find
    find /usr/share/fonts -iname 'LiberationSans-Regular.ttf' -o -iname 'DejaVuSans.ttf' 2>/dev/null | head -1
}

step07_fonts() {
    local fontsdir="$WINEPREFIX/drive_c/windows/Fonts"
    mkdir -p "$fontsdir"

    # --- Segoe UI ---
    local src; src="$(find_sans_font)"
    if [[ -z "$src" ]]; then
        msg "Schritt 7: Schriften" "Keine Ersatz-Sans-Schrift gefunden (Liberation/DejaVu).\nBitte 'ttf-liberation' bzw. 'dejavu-fonts' installieren."
        return 1
    fi
    run cp "$src" "$fontsdir/segoeui.ttf"
    run wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes' /v 'Segoe UI' /t REG_SZ /d 'Segoe UI' /f
    run wine reg add 'HKCU\Software\Wine\Fonts\Replacements' /v 'Segoe UI' /t REG_SZ /d 'Liberation Sans' /f

    # --- Consolas ---
    run wine reg add 'HKCU\Software\Wine\Fonts\Replacements' /v 'Consolas' /t REG_SZ /d 'Liberation Mono' /f

    # --- Segoe MDL2 Assets (prozedural via make-mdl2.py) ---
    if [[ -f "$MDL2_SCRIPT" ]] && command -v python3 &>/dev/null; then
        with_info "Schritt 7: Schriften" "Erzeuge Segoe-MDL2-Ersatzschrift (Titelleisten-Icons) ..." \
            python3 "$MDL2_SCRIPT" "$fontsdir/segmdl2.ttf"
        run wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' /v 'Segoe MDL2 Assets (TrueType)' /t REG_SZ /d 'segmdl2.ttf' /f
    else
        log "make-mdl2.py oder python3 fehlt - MDL2 übersprungen"
    fi

    check07_fonts
}

check07_fonts() {
    local out="" ok=0 f
    for f in segoeui.ttf segmdl2.ttf; do
        if [[ -f "$WINEPREFIX/drive_c/windows/Fonts/$f" ]]; then out+="OK    $f\n"; else out+="FEHLT $f\n"; [[ "$f" == segoeui.ttf ]] && ok=1; fi
    done
    show_result "Schritt 7: PRÜFEN" "$ok" "$out\n(segmdl2.ttf ist optional - nur Titelleisten-Icons.)"
    return $ok
}

# ===========================================================================
# SCHRITT 8: Firewall (KNXnet/IP UDP 3671)
# ===========================================================================
step08_firewall() {
    if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -qi active; then
        with_info "Schritt 8: Firewall" "Öffne UDP 3671 via ufw ..." \
            sudo ufw allow 3671/udp
    elif command -v firewall-cmd &>/dev/null && sudo firewall-cmd --state 2>/dev/null | grep -qi running; then
        with_info "Schritt 8: Firewall" "Öffne UDP 3671 via firewalld ..." \
            sudo firewall-cmd --permanent --add-port=3671/udp
        run sudo firewall-cmd --reload
    else
        msg "Schritt 8: Firewall" "Keine aktive Firewall (ufw/firewalld) erkannt.\n\nKNXnet/IP nutzt UDP-Port 3671. Ohne aktive Firewall ist nichts zu tun.\nFalls du eine andere Firewall nutzt, Port 3671/udp manuell freigeben."
    fi
    return 0
}

# ===========================================================================
# SCHRITT 9: WPF-Software-Modus + Desktop-Integration
# ===========================================================================
step09_wpf() {
    # WICHTIG: ohne DisableHWAcceleration bleibt das Hauptfenster schwarz.
    run wine reg add 'HKCU\SOFTWARE\Microsoft\Avalon.Graphics' /v DisableHWAcceleration /t REG_DWORD /d 1 /f

    # WebView2-Stubs (nur Vorhandensein nötig)
    local guid='{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' ver='109.0.1518.140'
    run wine reg add "HKCU\\Software\\Microsoft\\EdgeUpdate\\ClientState\\$guid" /v pv /t REG_SZ /d "$ver" /f
    run wine reg add "HKCU\\Software\\Microsoft\\EdgeUpdate\\Clients\\$guid"     /v pv /t REG_SZ /d "$ver" /f
    run wine reg add 'HKCU\Software\Wine\AppDefaults\msedgewebview2.exe' /v Version /t REG_SZ /d 'win7' /f

    # DPI optional abfragen
    local dpi
    dpi=$(whiptail --backtitle "$BACKTITLE" --title "Schritt 9: DPI (optional)" \
          --menu "Skalierung für hochauflösende Monitore.\n(Bei Standard-Auflösung: 96 belassen.)" \
          "$WT_HEIGHT" "$WT_WIDTH" 5 \
          "96"  "100% (Standard)" \
          "120" "125%" \
          "144" "150%" \
          "192" "200%" \
          3>&1 1>&2 2>&3) || dpi="96"
    run wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "$dpi" /f

    check09_wpf
}

check09_wpf() {
    local ok=1
    wine reg query 'HKCU\SOFTWARE\Microsoft\Avalon.Graphics' /v DisableHWAcceleration 2>/dev/null | grep -q '0x1' && ok=0
    show_result "Schritt 9: PRÜFEN" "$ok" \
        "$([[ $ok == 0 ]] && echo 'WPF-Software-Modus aktiv (DisableHWAcceleration=1).' || echo 'DisableHWAcceleration nicht gesetzt - Hauptfenster bliebe schwarz.')"
    return $ok
}

# ===========================================================================
# SCHRITT 10: USB-Lizenz-Dongle (udev-Regel)
# ===========================================================================
UDEV_RULE="/etc/udev/rules.d/90-knx-usb.rules"
step10_udev() {
    local grp="plugdev"
    getent group plugdev &>/dev/null || grp="users"
    local rule="SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"2a07\", ATTRS{idProduct}==\"0102\", MODE=\"0660\", GROUP=\"$grp\", TAG+=\"uaccess\""

    with_info "Schritt 10: Dongle" "Schreibe udev-Regel ($UDEV_RULE, GROUP=$grp) ..." \
        bash -c "echo '$rule' | sudo tee '$UDEV_RULE' >/dev/null"
    run sudo udevadm control --reload-rules
    run sudo udevadm trigger

    msg "Schritt 10: Dongle" \
"udev-Regel geschrieben (GROUP=$grp).

Bitte den KNX-USB-Dongle jetzt aus- und wieder einstecken.

Danach PRÜFEN im Menü (Punkt 10 erneut) oder:
  lsusb | grep -i 2a07"
    check10_udev
}

check10_udev() {
    local ok=1 detail
    if lsusb 2>/dev/null | grep -qi '2a07'; then ok=0; detail="Dongle erkannt (Vendor 2a07)."
    else detail="Dongle nicht gefunden. Gesteckt? Aus/Einstecken nach Regel-Reload noetig.\nRegel-Datei: $([[ -f $UDEV_RULE ]] && echo vorhanden || echo FEHLT)"; fi
    show_result "Schritt 10: PRÜFEN" "$ok" "$detail"
    return $ok
}

# ===========================================================================
# SCHRITT 11: ETS starten
# ===========================================================================
step11_launch() {
    if [[ ! -f "$WINEPREFIX/$ETS_DIR_REL/ETS6N.exe" ]]; then
        msg "Schritt 11: Start" "ETS6N.exe nicht gefunden. Erst Schritt 6 (Installation) durchführen."
        return 1
    fi
    yesno "Schritt 11: Start" \
"ETS6 wird jetzt gestartet.

Erwartung:
- Splash-Screen (grün, KNX-Logo)
- Hauptfenster mit Inhalt (nicht schwarz -> sonst Schritt 9 prüfen)
- Mit Dongle: Lizenz erkannt. Cloud-Lizenz nach Login. Ohne: Demo.

Starten?" || return 0

    clear
    echo "Starte ETS6N.exe ... (dieses Terminal zeigt Wine-Ausgaben, Fenster kommt separat)"
    WINEPREFIX="$WINEPREFIX" wine "C:\\Program Files (x86)\\ETS6\\ETS6N.exe" >>"$LOGFILE" 2>&1 &
    disown
    sleep 3
    msg "Schritt 11: Start" "ETS6 wurde gestartet (im Hintergrund).\n\nFalls kein Fenster erscheint oder es schwarz bleibt:\nLog prüfen ($LOGFILE) und Schritt 9 kontrollieren."
}

# ===========================================================================
# Alle Schritte nacheinander
# ===========================================================================
run_all() {
    yesno "Alle Schritte" \
"Schritte 1 bis 10 werden nacheinander ausgeführt.

Das umfasst längere, mehrminütige winetricks-Läufe (Schritt 4/5) 
und den interaktiven ETS-Installer (Schritt 6). 

Fortfahren?" || return
    step01_packages || { yesno "Weiter?" "Schritt 1 nicht sauber. Trotzdem weiter?" || return; }
    step02_wine     || { yesno "Weiter?" "Wine zu alt/fehlt. Trotzdem weiter?" || return; }
    step03_prefix   || { yesno "Weiter?" "Prefix-Problem. Trotzdem weiter?" || return; }
    step04_dotnet   || { yesno "Weiter?" "Schritt 4 nicht sauber. Trotzdem weiter?" || return; }
    step05_vcrun    || { yesno "Weiter?" "Schritt 5 nicht sauber. Trotzdem weiter?" || return; }
    step06_ets      || { yesno "Weiter?" "Schritt 6 nicht sauber. Trotzdem weiter?" || return; }
    step07_fonts    || { yesno "Weiter?" "Schritt 7 nicht sauber. Trotzdem weiter?" || return; }
    step08_firewall
    step09_wpf      || { yesno "Weiter?" "Schritt 9 nicht sauber. Trotzdem weiter?" || return; }
    step10_udev
    msg "Fertig" "Alle Schritte durchlaufen.\n\nETS jetzt via Menuepunkt 11 starten."
}

# ===========================================================================
# Wine-Prefix aendern (zur Laufzeit)
# ===========================================================================
change_prefix() {
    local new
    new=$(whiptail --backtitle "$BACKTITLE" --title "Wine-Prefix aendern" \
        --inputbox "Pfad zum Wine-Prefix eingeben.\n\nAktuell: $WINEPREFIX\n\n(~ und \$HOME werden aufgeloest. Der Ordner wird bei\nSchritt 3 angelegt, falls er noch nicht existiert.)" \
        "$WT_HEIGHT" "$WT_WIDTH" "$WINEPREFIX" 3>&1 1>&2 2>&3) || return 0

    # Leer -> abbrechen
    [[ -z "$new" ]] && return 0

    # ~ und $HOME/Variablen aufloesen
    new="${new/#\~/$HOME}"
    eval "new=\"$new\""

    # Muss ein absoluter Pfad sein
    if [[ "$new" != /* ]]; then
        msg "Wine-Prefix aendern" "Bitte einen absoluten Pfad angeben (beginnend mit /).\n\nNicht uebernommen: $new"
        return 1
    fi

    WINEPREFIX="$new"
    export WINEPREFIX
    log "WINEPREFIX geaendert auf: $WINEPREFIX"

    local status
    if [[ -d "$WINEPREFIX/drive_c/windows/system32" ]]; then
        status="Dieser Prefix existiert bereits (drive_c gefunden). Schritt 3 kann uebersprungen werden."
    else
        status="Dieser Prefix existiert noch NICHT. Schritt 3 legt ihn an."
    fi
    msg "Wine-Prefix aendern" "Neuer Prefix uebernommen:\n$WINEPREFIX\n\n$status"
}

# ===========================================================================
# Hauptmenü
# ===========================================================================
main_menu() {
    local choice
    while true; do
        choice=$(whiptail --backtitle "$BACKTITLE" \
            --title "WineEts - Hauptmenue" \
            --menu "Distro: $DISTRO   |   Prefix: $WINEPREFIX\n\nSchritt wählen (oder A für alle nacheinander):" \
            "$WT_HEIGHT" "$WT_WIDTH" "$WT_MENU_HEIGHT" \
            "A"  "ALLE Schritte 1-10 nacheinander" \
            "1"  "Systempakete installieren" \
            "2"  "Wine-Version prüfen (>= 11.10)" \
            "3"  "Wine-Prefix anlegen" \
            "4"  ".NET 4.0 + 4.8 installieren" \
            "5"  "VC++ Runtime + GDI+ + Windows-Schriften" \
            "6"  "ETS 6.4.1 installieren" \
            "7"  "Schriftarten" \
            "8"  "Firewall (KNXnet/IP 3671)" \
            "9"  "WPF-SW-Modus + Desktop" \
            "10" "USB-Lizenz-Dongle (udev)" \
            "11" "ETS starten" \
            "P"  "Wine-Prefix aendern (aktuell: $WINEPREFIX)" \
            "L"  "Logdatei anzeigen" \
            "Q"  "Beenden" \
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
                    whiptail --backtitle "$BACKTITLE" --title "Logdatei (Pfeiltasten scrollen, Tab -> OK -> Enter zum Schliessen)" \
                        --scrolltext --textbox "$LOGFILE" "$WT_HEIGHT" "$WT_WIDTH"
                else
                    msg "Logdatei" "Log ist noch leer:\n$LOGFILE"
                fi ;;
            Q)  break ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
main() {
    command -v whiptail &>/dev/null || { echo "whiptail fehlt (Paket: newt/libnewt). Bitte installieren."; exit 1; }
    log "WineEts (wineets.sh) v$VERSION gestartet. Distro=$DISTRO Prefix=$WINEPREFIX"
    msg "WineEts - Willkommen" \
"Dieses Skript richtet ETS 6.4.1 unter Wine ein.

Es modifiziert KEINE ETS/KNX-Binaries. ETS wird unverändert
installiert, nur die Wine-Umgebung wird vorbereitet.

Erkannte Distribution: $DISTRO
Wine-Prefix:           $WINEPREFIX
Logdatei:              $LOGFILE

Bedienung: Pfeiltasten wählen, Tab wechselt zu den Buttons
(OK / Abbrechen), Enter/Leertaste bestätigt.

Im Menü die Schritte 1 bis 11 der Reihe nach abarbeiten."
    main_menu
    clear
    echo "Beendet. Log: $LOGFILE"
}

main "$@"
