#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Robert Gerigk
"""Minimaler Segoe-MDL2-Assets-Ersatz für ETS6 unter Wine.

Erzeugt eine segmdl2.ttf mit den Fenster-Chrome-Symbolen die ETS6 in der
Titelleiste nutzt (close/minimize/maximize/restore). Vereinfachte Glyphen,
für ETS ausreichend. Benötigt python-fonttools.

Aufruf:
    python3 make-mdl2.py /pfad/zu/segmdl2.ttf
"""
import sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

EM = 2048
# Codepoints die ETS6 für die Titelleisten-Buttons nutzt
CP = {0xE106: "close", 0xE73C: "indeterminate", 0xE921: "minimize",
      0xE922: "maximize", 0xE923: "restore", 0xEB90: "projectclose"}
ORDER = [".notdef"] + list(dict.fromkeys(CP.values()))


def box(pen, x0, y0, x1, y1, t=90):
    # gefuellter Rechteck-Rahmen (aussen CW, innen CCW = hohl)
    pen.moveTo((x0, y0)); pen.lineTo((x1, y0)); pen.lineTo((x1, y1)); pen.lineTo((x0, y1)); pen.closePath()
    pen.moveTo((x0+t, y0+t)); pen.lineTo((x0+t, y1-t)); pen.lineTo((x1-t, y1-t)); pen.lineTo((x1-t, y0+t)); pen.closePath()


def stroke_h(pen, x0, x1, y, t=90):
    pen.moveTo((x0, y-t)); pen.lineTo((x1, y-t)); pen.lineTo((x1, y+t)); pen.lineTo((x0, y+t)); pen.closePath()


def draw(name, pen):
    if name == "minimize":
        stroke_h(pen, 400, 1400, 300)
    elif name == "maximize":
        box(pen, 400, 300, 1400, 1300)
    elif name == "restore":
        box(pen, 300, 200, 1250, 1150)
        box(pen, 550, 450, 1500, 1400)
    elif name in ("close", "projectclose"):
        pen.moveTo((400, 350)); pen.lineTo((520, 230)); pen.lineTo((1500, 1210)); pen.lineTo((1380, 1330)); pen.closePath()
        pen.moveTo((1380, 230)); pen.lineTo((1500, 350)); pen.lineTo((520, 1330)); pen.lineTo((400, 1210)); pen.closePath()
    elif name == "indeterminate":
        stroke_h(pen, 500, 1300, 800)
    else:  # .notdef
        box(pen, 200, 100, 900, 1400, t=70)


fb = FontBuilder(EM, isTTF=True)
fb.setupGlyphOrder(ORDER)
fb.setupCharacterMap(CP)
glyphs, metrics = {}, {}
for n in ORDER:
    pen = TTGlyphPen(None)
    draw(n, pen)
    glyphs[n] = pen.glyph()
    metrics[n] = (1800, 0)
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics(metrics)
fb.setupHorizontalHeader(ascent=1638, descent=-410)
fb.setupNameTable({"familyName": "Segoe MDL2 Assets", "styleName": "Regular",
                   "fullName": "Segoe MDL2 Assets", "psName": "SegoeMDL2Assets-Regular"})
fb.setupOS2(sTypoAscender=1638, sTypoDescender=-410, usWinAscent=1638, usWinDescent=410)
fb.setupPost()
out = sys.argv[1] if len(sys.argv) > 1 else "segmdl2.ttf"
fb.save(out)
print("geschrieben:", out)
