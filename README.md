# Baumängel Tracker

Mängelprotokoll mit Fotodokumentation für das iPhone. Räume anlegen, Mängel mit
Foto und Notiz erfassen, abhaken — und am Schluss ein sauberes PDF-Protokoll
weitergeben.

Kein Konto, keine Werbung, keine Analyse. Alle Daten und Fotos bleiben auf dem
Gerät.

<p>
  <img src="AppStore/screenshots/1-projekte.png" width="200" alt="Projektliste">
  <img src="AppStore/screenshots/2-raeume.png" width="200" alt="Räume mit Fortschritt">
  <img src="AppStore/screenshots/3-maengel.png" width="200" alt="Mängelliste mit Filter">
  <img src="AppStore/screenshots/5-pdf.png" width="200" alt="PDF-Protokoll">
</p>

## Funktionen

- **Projekte** — Objekt mit Name, Adresse und Datum; mehrere parallel führen
- **Räume** — je Projekt, in eigener Reihenfolge, mit Fortschritt je Raum
- **Mängel** — Titel, Notiz, Frist, Status offen/behoben mit Behoben-Datum
- **Fotos** — aus der Kamera oder der Mediathek, mehrere je Mangel, im Vollbild
- **PDF-Protokoll** — A4 mit Kopfdaten, Zusammenfassung, Abschnitten je Raum,
  Fotos und Seitenzahlen; teilbar über das System-Teilen
- **Filter** — alle, offen, behoben; überfällige Fristen sind markiert

## Technik

| | |
|---|---|
| Sprache | Swift 5, SwiftUI |
| Datenhaltung | SwiftData, Fotos als JPEG im Datenbereich der App |
| PDF | `UIGraphicsPDFRenderer`, eigener Seitensatz mit Umbruchlogik |
| Mindestversion | iOS 17 |
| Geräte | iPhone, Hochformat |
| Abhängigkeiten | keine |

## Selbst bauen

Das Xcode-Projekt wird aus `project.yml` erzeugt und liegt deshalb nicht im
Repo:

```bash
brew install xcodegen
xcodegen generate
open BaumaengelTracker.xcodeproj
```

Für einen Lauf im Simulator ohne eigenes Entwicklerkonto:

```bash
xcodebuild -project BaumaengelTracker.xcodeproj -scheme BaumaengelTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build
```

Mit dem Startargument `-seedDemo` legt die App beim ersten Start neutrale
Beispieldaten an — dafür ist `scripts/screenshots.sh` gedacht.

## App-Store-Paket

Bundle-ID und App-Store-Profil liegen im Entwicklerkonto; signiert wird bewusst
manuell, weil Xcode beim Archivieren mit automatischer Signatur ein
Entwicklungsprofil samt registriertem Gerät verlangt.

```bash
bash AppStore/build-ipa.sh bauen      # Archiv + IPA, prüft die Kamera-Begründung im Paket
bash AppStore/build-ipa.sh pruefen    # altool --validate-app
bash AppStore/build-ipa.sh hochladen  # altool --upload-app
```

## Aufbau

```
BaumaengelTracker/
├── App/      Einstieg, Info.plist, Privacy-Manifest
├── Model/    SwiftData-Modelle, Fotospeicher, Demodaten
├── Views/    Projekte → Räume → Mängel, Editor, Galerie, PDF-Vorschau
└── Export/   PdfProtokoll — A4-Satz mit Seitenumbruch
```

## Datenschutz

Siehe [PRIVACY.md](PRIVACY.md). Kurzfassung: Die App erfasst nichts, sendet
nichts und braucht kein Konto.

## Lizenz

MIT — siehe [LICENSE](LICENSE).
