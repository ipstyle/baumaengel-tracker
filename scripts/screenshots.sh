#!/bin/bash
# Store-Bildschirmfotos im Pflichtmass 6,9" (1320×2868) aufnehmen.
#
#   bash scripts/screenshots.sh vorbereiten     # bauen, frisch installieren, Demodaten, saubere Statusleiste
#   bash scripts/screenshots.sh bild 1-projekte # aktuellen Bildschirm ablegen
#
# Zwischen den Aufnahmen wird von Hand (oder per Werkzeug) navigiert.
# Das Teilen-Menü NICHT fotografieren — dort erscheinen fremde App-Symbole
# (Guideline 5.2.5 gilt auch für Bilder).
set -euo pipefail

GERAET="${GERAET:-iPhone 17 Pro Max}"
BUNDLE="com.ip-style.baumaengeltracker"
WURZEL="$(cd "$(dirname "$0")/.." && pwd)"
ZIEL="$WURZEL/AppStore/screenshots"

udid() {
    xcrun simctl list devices available \
        | grep -m1 "$GERAET (" \
        | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

case "${1:-}" in
vorbereiten)
    UDID="$(udid)"
    [ -n "$UDID" ] || { echo "✗ Simulator «$GERAET» nicht gefunden"; exit 1; }
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b >/dev/null

    xcodebuild -project "$WURZEL/BaumaengelTracker.xcodeproj" \
               -scheme BaumaengelTracker -configuration Debug \
               -destination "platform=iOS Simulator,id=$UDID" \
               -derivedDataPath "$WURZEL/build/dd" \
               CODE_SIGNING_ALLOWED=NO build >/dev/null

    xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl install "$UDID" \
        "$WURZEL/build/dd/Build/Products/Debug-iphonesimulator/BaumaengelTracker.app"

    # Neutrale Statusleiste, wie Apple sie in eigenen Bildern zeigt
    xcrun simctl status_bar "$UDID" override \
        --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

    xcrun simctl launch "$UDID" "$BUNDLE" -seedDemo
    mkdir -p "$ZIEL"
    echo "✓ bereit — jetzt navigieren und «bild <name>» aufrufen"
    ;;
bild)
    UDID="$(udid)"
    NAME="${2:?Name fehlt}"
    mkdir -p "$ZIEL"
    xcrun simctl io "$UDID" screenshot --type png "$ZIEL/$NAME.png"
    sips -g pixelWidth -g pixelHeight "$ZIEL/$NAME.png" | tail -2
    ;;
zuruecksetzen)
    UDID="$(udid)"
    xcrun simctl status_bar "$UDID" clear
    echo "✓ Statusleiste zurückgesetzt"
    ;;
*)
    sed -n '2,10p' "$0"
    exit 1
    ;;
esac
