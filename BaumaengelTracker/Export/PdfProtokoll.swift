import UIKit

/// Erzeugt aus einem Projekt ein A4-Protokoll: Deckkopf, je Raum ein Abschnitt,
/// je Mangel ein Block mit Status, Fristen, Notiz und Fotos.
enum PdfProtokoll {

    enum Fehler: LocalizedError {
        case schreiben

        var errorDescription: String? {
            "Die Datei konnte nicht abgelegt werden. Prüfe den freien Speicher und versuche es erneut."
        }
    }

    /// Läuft bewusst auf einem Abzug der Daten, nicht auf den Modellen — so
    /// kann der Satz im Hintergrund laufen, während die Oberfläche bedienbar bleibt.
    static func erstellen(aus daten: ProtokollDaten) throws -> URL {
        let beginn = Date.now
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Mängelprotokoll \(daten.name)",
            kCGPDFContextCreator as String: "Baumängel Tracker"
        ]
        // Erster Durchgang nur zum Zählen, damit «Seite 2 von 5» stimmen kann.
        // Je Durchgang ein eigener Renderer — ein zweiter Lauf auf demselben
        // liefert ein leeres Dokument.
        var seitenZahl = 0
        _ = UIGraphicsPDFRenderer(bounds: Seitensatz.seite, format: format).pdfData { kontext in
            let satz = Seitensatz(kontext: kontext, daten: daten, gesamt: nil)
            zeichnen(daten: daten, satz: satz)
            seitenZahl = satz.seitenzahl
        }

        let bytes = UIGraphicsPDFRenderer(bounds: Seitensatz.seite, format: format).pdfData { kontext in
            let satz = Seitensatz(kontext: kontext, daten: daten, gesamt: seitenZahl)
            zeichnen(daten: daten, satz: satz)
        }

        guard !bytes.isEmpty else { throw Fehler.schreiben }

        let name = dateiname(daten)
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try bytes.write(to: ziel, options: .atomic)
        } catch {
            throw Fehler.schreiben
        }
        #if DEBUG
        let fotos = daten.raeume.flatMap(\.maengel).reduce(0) { $0 + $1.fotoNamen.count }
        print(String(format: "[PDF] %d Mängel, %d Fotos → %d Seiten, %.1f MB, %.2f s",
                     daten.anzahlMaengel, fotos, seitenZahl,
                     Double(bytes.count) / 1_048_576,
                     Date.now.timeIntervalSince(beginn)))
        #endif
        return ziel
    }

    static func dateiname(_ projekt: ProtokollDaten) -> String {
        let erlaubt = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let sauber = projekt.name.unicodeScalars
            .map { erlaubt.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .trimmed
        let datum = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "Mängelprotokoll \(sauber.isEmpty ? "Projekt" : sauber) \(datum).pdf"
    }

    // MARK: - Aufbau

    private static func zeichnen(daten: ProtokollDaten, satz: Seitensatz) {
        satz.neueSeite()
        satz.kopfblock(daten)

        for (index, raum) in daten.raeume.enumerated() {
            let nummerRaum = index + 1
            satz.raumTitel(nummer: nummerRaum, raum: raum)
            for (position, mangel) in raum.maengel.enumerated() {
                satz.mangelBlock(nummer: "\(nummerRaum).\(position + 1)", mangel: mangel)
            }
        }

        if daten.anzahlMaengel == 0 {
            satz.absatz("In diesem Projekt ist noch kein Mangel erfasst.",
                        schrift: .systemFont(ofSize: 11), farbe: .darkGray)
        }
    }
}

// MARK: - Seitensatz

private final class Seitensatz {

    static let seite = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    private let rand: CGFloat = 48
    private let fussHoehe: CGFloat = 30

    private let kontext: UIGraphicsPDFRendererContext
    private let daten: ProtokollDaten
    private let gesamt: Int?

    private(set) var seitenzahl = 0
    private var y: CGFloat = 0

    private var breite: CGFloat { Seitensatz.seite.width - 2 * rand }
    private var unterkante: CGFloat { Seitensatz.seite.height - rand - fussHoehe }

    init(kontext: UIGraphicsPDFRendererContext, daten: ProtokollDaten, gesamt: Int?) {
        self.kontext = kontext
        self.daten = daten
        self.gesamt = gesamt
    }

    // MARK: Seiten

    func neueSeite() {
        kontext.beginPage()
        seitenzahl += 1
        y = rand
        if seitenzahl > 1 { laufenderKopf() }
        fusszeile()
    }

    private func platz(_ hoehe: CGFloat) {
        if y + hoehe > unterkante { neueSeite() }
    }

    private func laufenderKopf() {
        let text = "Mängelprotokoll · \(daten.name)"
        zeichne(text, schrift: .systemFont(ofSize: 8), farbe: .gray,
                bei: CGRect(x: rand, y: rand - 14, width: breite, height: 12))
        linie(bei: rand - 2, farbe: UIColor.black.withAlphaComponent(0.12))
    }

    private func fusszeile() {
        let basis = Seitensatz.seite.height - rand - 10
        linie(bei: basis - 8, farbe: UIColor.black.withAlphaComponent(0.12))
        zeichne(Date.now.kurzDatum, schrift: .systemFont(ofSize: 8), farbe: .gray,
                bei: CGRect(x: rand, y: basis, width: breite / 2, height: 12))
        let seitenText = gesamt.map { "Seite \(seitenzahl) von \($0)" } ?? "Seite \(seitenzahl)"
        zeichne(seitenText, schrift: .systemFont(ofSize: 8), farbe: .gray,
                bei: CGRect(x: rand + breite / 2, y: basis, width: breite / 2, height: 12),
                ausrichtung: .right)
    }

    // MARK: Blöcke

    func kopfblock(_ projekt: ProtokollDaten) {
        zeichne("MÄNGELPROTOKOLL", schrift: .systemFont(ofSize: 10, weight: .semibold),
                farbe: UIColor(red: 0.85, green: 0.42, blue: 0.10, alpha: 1),
                bei: CGRect(x: rand, y: y, width: breite, height: 14))
        y += 20

        y += absatzHoehe(projekt.name, schrift: .systemFont(ofSize: 24, weight: .bold),
                         zeichnen: true, farbe: .black)
        if !projekt.adresse.isEmpty {
            y += 2
            y += absatzHoehe(projekt.adresse, schrift: .systemFont(ofSize: 12),
                             zeichnen: true, farbe: .darkGray)
        }
        y += 14

        let zusammenfassung = "\(maengelText(projekt.anzahlMaengel)) · "
            + "\(projekt.anzahlOffen) offen · \(projekt.anzahlBehoben) behoben"
        kasten(hoehe: 34)
        zeichne(zusammenfassung, schrift: .systemFont(ofSize: 11, weight: .medium), farbe: .black,
                bei: CGRect(x: rand + 12, y: y + 11, width: breite - 24, height: 14))
        y += 34 + 18

        linie(bei: y, farbe: UIColor.black.withAlphaComponent(0.15))
        y += 16
    }

    func raumTitel(nummer: Int, raum: RaumDaten) {
        platz(60)
        y += 6

        // Dasselbe Zeichen wie in der App — das Protokoll wird damit auf einen
        // Blick lesbar, auch für jemanden, der es nur überfliegt.
        let akzent = UIColor(red: 0.85, green: 0.42, blue: 0.10, alpha: 1)
        let einstellung = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let zeichen = UIImage(systemName: raumSymbol(raum.name), withConfiguration: einstellung)?
            .withTintColor(akzent, renderingMode: .alwaysOriginal) {
            // Direkt in den PDF-Kontext gezeichnet wird aus dem Symbol ein
            // volles Rechteck. Der Umweg über ein Bitmap mit Alphakanal behält
            // die Form.
            let masse = CGSize(width: 15, height: 14)
            let art = UIGraphicsImageRendererFormat.default()
            art.opaque = false
            art.scale = 4
            let bitmap = UIGraphicsImageRenderer(size: masse, format: art).image { _ in
                zeichen.draw(in: einpassen(zeichen.size, in: CGRect(origin: .zero, size: masse)))
            }
            bitmap.draw(in: CGRect(x: rand, y: y + 3, width: masse.width, height: masse.height))
        }

        zeichne("\(nummer). \(raum.name)", schrift: .systemFont(ofSize: 15, weight: .semibold),
                farbe: .black, bei: CGRect(x: rand + 22, y: y, width: breite - 142, height: 20))
        let rechts = raum.anzahlMaengel == 0
            ? ""
            : "\(maengelText(raum.anzahlMaengel)) · \(raum.anzahlOffen) offen"
        zeichne(rechts, schrift: .systemFont(ofSize: 9), farbe: .gray,
                bei: CGRect(x: rand + breite - 160, y: y + 6, width: 160, height: 12),
                ausrichtung: .right)
        y += 22
        linie(bei: y, farbe: UIColor.black.withAlphaComponent(0.15))
        y += 12
    }

    func mangelBlock(nummer: String, mangel: MangelDaten) {
        // Einen Mangel möglichst nicht über die Seitenkante brechen — sonst
        // steht ein einzelnes Foto verwaist auf der nächsten Seite.
        platz(min(blockHoehe(mangel), unterkante - rand))

        // Kopfzeile: Nummer, Titel, Status
        let statusBreite: CGFloat = 74
        let titelBreite = breite - 34 - statusBreite - 8
        zeichne(nummer, schrift: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                farbe: .gray, bei: CGRect(x: rand, y: y + 1, width: 32, height: 14))
        let titelHoehe = absatzHoehe(mangel.titel, schrift: .systemFont(ofSize: 12, weight: .semibold),
                                     zeichnen: true, farbe: .black,
                                     x: rand + 34, breite: titelBreite)
        statusMarke(mangel: mangel,
                    rahmen: CGRect(x: rand + breite - statusBreite, y: y, width: statusBreite, height: 16))
        y += max(titelHoehe, 16)
        y += 4

        // Zeile mit den Daten
        var teile = ["erfasst \(mangel.erfasstAm.kurzDatum)"]
        if let frist = mangel.frist, !mangel.behoben {
            teile.append("Frist \(frist.kurzDatum)")
        }
        if let behobenAm = mangel.behobenAm {
            teile.append("behoben \(behobenAm.kurzDatum)")
        }
        zeichne(teile.joined(separator: "   ·   "), schrift: .systemFont(ofSize: 9),
                farbe: .gray, bei: CGRect(x: rand + 34, y: y, width: breite - 34, height: 12))
        y += 15

        if !mangel.notiz.isEmpty {
            absatz(mangel.notiz, schrift: .systemFont(ofSize: 10.5), farbe: .darkGray,
                   x: rand + 34, breite: breite - 34)
            y += 4
        }

        if !mangel.fotoNamen.isEmpty {
            fotoRaster(mangel.fotoNamen, x: rand + 34, breite: breite - 34)
        }

        y += 10
        linie(bei: y, farbe: UIColor.black.withAlphaComponent(0.08))
        y += 12
    }

    /// Geschätzte Gesamthöhe eines Mangelblocks — Grundlage für den Seitenumbruch.
    private func blockHoehe(_ mangel: MangelDaten) -> CGFloat {
        let titelSchrift = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let notizSchrift = UIFont.systemFont(ofSize: 10.5)
        let inhalt = breite - 34

        var hoehe = max(CGFloat(umbrechen(mangel.titel, schrift: titelSchrift,
                                          breite: inhalt - 82).count) * titelSchrift.lineHeight, 16)
        hoehe += 4 + 15
        if !mangel.notiz.isEmpty {
            hoehe += CGFloat(umbrechen(mangel.notiz, schrift: notizSchrift,
                                       breite: inhalt).count) * notizSchrift.lineHeight + 4
        }
        if !mangel.fotoNamen.isEmpty {
            let zelle = (inhalt - 16) / 3
            let reihen = CGFloat((mangel.fotoNamen.count + 2) / 3)
            hoehe += reihen * zelle * 0.72 + (reihen - 1) * 8
        }
        return hoehe + 22
    }

    /// Fliesstext mit Zeilenumbruch über Seitengrenzen hinweg.
    func absatz(_ text: String, schrift: UIFont, farbe: UIColor,
                x: CGFloat? = nil, breite eigene: CGFloat? = nil) {
        let links = x ?? rand
        let weite = eigene ?? breite
        for zeile in umbrechen(text, schrift: schrift, breite: weite) {
            platz(schrift.lineHeight)
            zeichne(zeile, schrift: schrift, farbe: farbe,
                    bei: CGRect(x: links, y: y, width: weite, height: schrift.lineHeight))
            y += schrift.lineHeight
        }
    }

    private func fotoRaster(_ namen: [String], x: CGFloat, breite weite: CGFloat) {
        let abstand: CGFloat = 8
        let proReihe = 3
        let zelle = (weite - abstand * CGFloat(proReihe - 1)) / CGFloat(proReihe)
        let hoehe = zelle * 0.72

        for (index, name) in namen.enumerated() {
            let spalte = index % proReihe
            if spalte == 0 {
                platz(hoehe + abstand)
                if index > 0 { y += abstand }
            }
            let rahmen = CGRect(x: x + CGFloat(spalte) * (zelle + abstand),
                                y: y, width: zelle, height: hoehe)
            UIColor(white: 0.94, alpha: 1).setFill()
            UIBezierPath(roundedRect: rahmen, cornerRadius: 4).fill()
            // Verkleinert und JPEG-codiert — sonst wird das Dokument riesig.
            if let bild = Fotospeicher.fuerDruck(name) {
                bild.draw(in: einpassen(bild.size, in: rahmen))
            }
        }
        y += hoehe
    }

    // MARK: Werkzeug

    private func statusMarke(mangel: MangelDaten, rahmen: CGRect) {
        let offen = UIColor(red: 0.85, green: 0.42, blue: 0.10, alpha: 1)
        let behoben = UIColor(red: 0.16, green: 0.55, blue: 0.31, alpha: 1)
        let ueberfaellig = UIColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 1)

        let farbe = mangel.behoben ? behoben : (mangel.ueberfaellig ? ueberfaellig : offen)
        let text = mangel.behoben ? "BEHOBEN" : (mangel.ueberfaellig ? "ÜBERFÄLLIG" : "OFFEN")

        farbe.withAlphaComponent(0.12).setFill()
        UIBezierPath(roundedRect: rahmen, cornerRadius: 8).fill()
        zeichne(text, schrift: .systemFont(ofSize: 8, weight: .semibold), farbe: farbe,
                bei: CGRect(x: rahmen.minX, y: rahmen.minY + 4, width: rahmen.width, height: 10),
                ausrichtung: .center)
    }

    private func kasten(hoehe: CGFloat) {
        UIColor(white: 0.96, alpha: 1).setFill()
        UIBezierPath(roundedRect: CGRect(x: rand, y: y, width: breite, height: hoehe),
                     cornerRadius: 6).fill()
    }

    private func linie(bei hoehe: CGFloat, farbe: UIColor) {
        farbe.setStroke()
        let pfad = UIBezierPath()
        pfad.move(to: CGPoint(x: rand, y: hoehe))
        pfad.addLine(to: CGPoint(x: rand + breite, y: hoehe))
        pfad.lineWidth = 0.5
        pfad.stroke()
    }

    @discardableResult
    private func absatzHoehe(_ text: String, schrift: UIFont, zeichnen zeichnenJa: Bool,
                             farbe: UIColor, x: CGFloat? = nil, breite eigene: CGFloat? = nil) -> CGFloat {
        let links = x ?? rand
        let weite = eigene ?? breite
        let zeilen = umbrechen(text, schrift: schrift, breite: weite)
        if zeichnenJa {
            var lauf = y
            for zeile in zeilen {
                zeichne(zeile, schrift: schrift, farbe: farbe,
                        bei: CGRect(x: links, y: lauf, width: weite, height: schrift.lineHeight))
                lauf += schrift.lineHeight
            }
        }
        return CGFloat(zeilen.count) * schrift.lineHeight
    }

    private func zeichne(_ text: String, schrift: UIFont, farbe: UIColor, bei rahmen: CGRect,
                         ausrichtung: NSTextAlignment = .left) {
        guard !text.isEmpty else { return }
        let stil = NSMutableParagraphStyle()
        stil.alignment = ausrichtung
        stil.lineBreakMode = .byClipping
        (text as NSString).draw(in: rahmen, withAttributes: [
            .font: schrift, .foregroundColor: farbe, .paragraphStyle: stil
        ])
    }

    /// Gieriger Wortumbruch — verlässlicher als eine Höhenschätzung, weil wir
    /// Zeile für Zeile zeichnen und dabei die Seite wechseln können.
    private func umbrechen(_ text: String, schrift: UIFont, breite weite: CGFloat) -> [String] {
        var ergebnis: [String] = []
        for absatzText in text.components(separatedBy: .newlines) {
            if absatzText.isEmpty {
                ergebnis.append("")
                continue
            }
            var zeile = ""
            for wort in absatzText.split(separator: " ", omittingEmptySubsequences: false) {
                let versuch = zeile.isEmpty ? String(wort) : zeile + " " + wort
                let masse = (versuch as NSString).size(withAttributes: [.font: schrift])
                if masse.width <= weite || zeile.isEmpty {
                    zeile = versuch
                } else {
                    ergebnis.append(zeile)
                    zeile = String(wort)
                }
            }
            ergebnis.append(zeile)
        }
        return ergebnis
    }

    private func einpassen(_ groesse: CGSize, in rahmen: CGRect) -> CGRect {
        guard groesse.width > 0, groesse.height > 0 else { return rahmen }
        let faktor = min(rahmen.width / groesse.width, rahmen.height / groesse.height)
        let ziel = CGSize(width: groesse.width * faktor, height: groesse.height * faktor)
        return CGRect(x: rahmen.midX - ziel.width / 2,
                      y: rahmen.midY - ziel.height / 2,
                      width: ziel.width, height: ziel.height)
    }
}
