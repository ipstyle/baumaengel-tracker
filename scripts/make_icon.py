#!/usr/bin/env python3
"""Erzeugt das App-Symbol (1024×1024) für Baumängel Tracker.

    python3 scripts/make_icon.py

Bewusst schlicht und ohne fremde Marken: dunkle Fläche, darauf eine
Mängelliste — erste Zeile abgehakt (grün), zweite offen (orange).
Wird direkt in den Asset-Katalog geschrieben.
"""
from pathlib import Path

from PIL import Image, ImageDraw

KANTE = 1024
ZIEL = Path(__file__).resolve().parents[1] / (
    "BaumaengelTracker/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

HINTERGRUND_OBEN = (36, 44, 58)
HINTERGRUND_UNTEN = (22, 27, 36)
PAPIER = (247, 248, 250)
LINIE = (176, 183, 194)
GRUEN = (41, 140, 79)
ORANGE = (217, 107, 26)


def verlauf(bild: Image.Image) -> None:
    zeichner = ImageDraw.Draw(bild)
    for y in range(KANTE):
        anteil = y / (KANTE - 1)
        farbe = tuple(
            round(HINTERGRUND_OBEN[i] + (HINTERGRUND_UNTEN[i] - HINTERGRUND_OBEN[i]) * anteil)
            for i in range(3))
        zeichner.line([(0, y), (KANTE, y)], fill=farbe)


def haken(zeichner: ImageDraw.ImageDraw, kasten, farbe, breite) -> None:
    x0, y0, x1, y1 = kasten
    b = x1 - x0
    zeichner.line(
        [(x0 + b * 0.22, y0 + b * 0.52),
         (x0 + b * 0.42, y0 + b * 0.72),
         (x0 + b * 0.80, y0 + b * 0.26)],
        fill=farbe, width=breite, joint="curve")


def main() -> int:
    bild = Image.new("RGB", (KANTE, KANTE), HINTERGRUND_OBEN)
    verlauf(bild)
    zeichner = ImageDraw.Draw(bild)

    # Blatt
    rand = 186
    blatt = (rand, 150, KANTE - rand, KANTE - 150)
    zeichner.rounded_rectangle(blatt, radius=52, fill=PAPIER)

    # Klemme oben
    klemme_breite = 220
    mitte = KANTE // 2
    zeichner.rounded_rectangle(
        (mitte - klemme_breite // 2, 104, mitte + klemme_breite // 2, 196),
        radius=40, fill=(206, 212, 222))

    # Drei Zeilen: behoben, offen, offen
    kasten_kante = 96
    links = rand + 70
    text_links = links + kasten_kante + 46
    text_rechts = KANTE - rand - 70
    zeilen = [
        (392, GRUEN, True),
        (566, ORANGE, False),
        (740, LINIE, False),
    ]
    for y, farbe, erledigt in zeilen:
        kasten = (links, y, links + kasten_kante, y + kasten_kante)
        if erledigt:
            zeichner.rounded_rectangle(kasten, radius=26, fill=farbe)
            haken(zeichner, kasten, PAPIER, 18)
        else:
            zeichner.rounded_rectangle(kasten, radius=26, outline=farbe, width=15)

        strich = y + kasten_kante // 2
        zeichner.line([(text_links, strich), (text_rechts, strich)],
                      fill=farbe if not erledigt else LINIE, width=26)

    ZIEL.parent.mkdir(parents=True, exist_ok=True)
    bild.save(ZIEL, "PNG")
    print(f"✓ {ZIEL} ({KANTE}×{KANTE})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
