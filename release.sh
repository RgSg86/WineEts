#!/usr/bin/env bash
#
# release.sh - taggt einen Release passend zur VERSION in wineets.sh
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Robert Gerigk
#
# Liest VERSION="x.y.z" aus wineets.sh und legt daraus den annotierten
# Git-Tag "vx.y.z" an. So driften Skript-Version und Tag nicht auseinander.
# Der Tag wird NICHT automatisch gepusht - der Befehl dafür wird am Ende
# ausgegeben (Push -> Codeberg/GitHub erzeugen daraus automatisch ein Release).

set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# VERSION aus wineets.sh lesen
version=$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' wineets.sh | head -1)
[[ -n "$version" ]] || { echo "FEHLER: VERSION nicht in wineets.sh gefunden." >&2; exit 1; }
tag="v$version"

# In einem Git-Repo?
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { echo "FEHLER: kein Git-Repository." >&2; exit 1; }

# Arbeitsverzeichnis muss sauber sein (sonst taggt man einen halben Stand)
if [[ -n "$(git status --porcelain)" ]]; then
    echo "FEHLER: Arbeitsverzeichnis nicht sauber - bitte erst committen:" >&2
    git status --short >&2
    exit 1
fi

# Tag darf noch nicht existieren
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "FEHLER: Tag $tag existiert bereits." >&2
    exit 1
fi

echo "Tagge $tag ..."
git tag -a "$tag" -m "WineEts $version"

echo
echo "Tag $tag angelegt. Zum Veröffentlichen:"
echo "  git push origin $tag        # legt auf Codeberg/GitHub automatisch ein Release an"
