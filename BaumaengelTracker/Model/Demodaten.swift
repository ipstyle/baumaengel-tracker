import SwiftUI
import SwiftData

/// Neutrale Beispieldaten für die Store-Bilder. Wird ausschliesslich mit dem
/// Startargument `-seedDemo` aufgerufen, nie im ausgelieferten Ablauf.
enum Demodaten {

    @MainActor
    static func anlegen(in kontext: ModelContext) {
        let vorhanden = (try? kontext.fetch(FetchDescriptor<Projekt>()))?.isEmpty == false
        guard !vorhanden else { return }

        let zweites = Projekt(name: "Neubau Sonnenhof, Haus B",
                              adresse: "Feldweg 4, 5442 Beispielhausen",
                              erstelltAm: tageVorher(38))
        kontext.insert(zweites)
        fuellen(zweites, mit: [
            ("Treppenhaus", [
                ("Handlauf wackelt", "Befestigung im zweiten Obergeschoss.", false, 10, 1),
                ("Farbnase an der Wand", "Auf Augenhöhe beim Fenster.", true, 20, 0)
            ]),
            ("Keller", [
                ("Tür schliesst nicht bündig", "Schloss muss justiert werden.", false, 8, 1)
            ])
        ], in: kontext)

        let projekt = Projekt(name: "Musterhaus, Wohnung 3.1",
                              adresse: "Beispielweg 12, 5443 Musterdorf",
                              erstelltAm: tageVorher(21))
        kontext.insert(projekt)

        fuellen(projekt, mit: [
            ("Küche", [
                ("Kratzer in der Arbeitsplatte", "Rund 12 cm lang, rechts neben dem Kochfeld. Nachbesserung durch den Schreiner vereinbart.", false, 12, 2),
                ("Schubladenfront sitzt schief", "Spaltmass oben 4 mm, unten 1 mm.", false, 11, 1),
                ("Silikonfuge unsauber", "Fuge beim Spültisch nachgezogen.", true, 18, 1)
            ]),
            ("Bad", [
                ("Fliese mit Riss", "Zweite Reihe über der Wanne, Ersatzplatte ist bestellt.", false, 9, 2),
                ("Duschtür schleift", "Tür streift beim Öffnen am Rahmen.", true, 16, 0)
            ]),
            ("Wohnzimmer", [
                ("Parkett wellt sich beim Fenster", "Auf etwa einem halben Meter spürbar. Feuchtigkeit wird gemessen.", false, 7, 2),
                ("Steckdose ohne Strom", "Rechts neben der Balkontür.", true, 15, 0),
                ("Malerarbeiten unvollständig", "Übergang zur Decke muss nachgezogen werden.", false, 5, 1)
            ]),
            ("Balkon", [
                ("Abschlussblech verbeult", "Auf der linken Seite, rund 30 cm.", false, 4, 1)
            ])
        ], in: kontext)

        try? kontext.save()
    }

    /// (Raumname, [(Titel, Notiz, behoben, vor wie vielen Tagen, Anzahl Fotos)])
    @MainActor
    private static func fuellen(_ projekt: Projekt,
                                mit inhalt: [(String, [(String, String, Bool, Int, Int)])],
                                in kontext: ModelContext) {
        for (index, eintrag) in inhalt.enumerated() {
            let raum = Raum(name: eintrag.0, reihenfolge: index)
            raum.projekt = projekt
            kontext.insert(raum)

            for (titel, notiz, behoben, tage, fotos) in eintrag.1 {
                let mangel = Mangel(titel: titel, notiz: notiz, erfasstAm: tageVorher(tage))
                mangel.raum = raum
                if behoben {
                    mangel.behoben = true
                    mangel.behobenAm = tageVorher(max(0, tage - 4))
                } else if tage > 6 {
                    mangel.frist = tageVorher(-(6 + tage % 17))
                }
                mangel.fotoNamen = (0..<fotos).compactMap { nummer in
                    Fotospeicher.speichern(Beispielbild.zeichnen(titel: titel, nummer: nummer))
                }
                kontext.insert(mangel)
            }
        }
    }

    private static func tageVorher(_ tage: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -tage, to: .now) ?? .now
    }
}

/// Platzhalterbilder — bewusst abstrakt, ohne fremde Marken oder Personen.
enum Beispielbild {

    static func zeichnen(titel: String, nummer: Int) -> UIImage {
        let groesse = CGSize(width: 1200, height: 900)
        let saat = abs(titel.hashValue &+ nummer &* 7919)

        // Drei Materialtöne, damit die Bilder nicht alle gleich aussehen.
        let toene: [(CGFloat, CGFloat, CGFloat)] = [
            (0.09, 0.05, 0.74),   // Beton
            (0.08, 0.16, 0.80),   // Platte, warm
            (0.07, 0.26, 0.62)    // Holz
        ]
        let ton = toene[saat % toene.count]

        return UIGraphicsImageRenderer(size: groesse).image { ctx in
            let kontext = ctx.cgContext

            UIColor(hue: ton.0, saturation: ton.1, brightness: ton.2, alpha: 1).setFill()
            kontext.fill(CGRect(origin: .zero, size: groesse))

            // Lichtverlauf von links oben
            if let verlauf = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [UIColor(white: 1, alpha: 0.22).cgColor,
                                                 UIColor(white: 0, alpha: 0.20).cgColor] as CFArray,
                                        locations: [0, 1]) {
                kontext.drawLinearGradient(verlauf, start: .zero,
                                           end: CGPoint(x: groesse.width, y: groesse.height),
                                           options: [])
            }

            // Körnung
            for i in 0..<9000 {
                let x = CGFloat((saat &+ i &* 3607) % Int(groesse.width))
                let y = CGFloat((saat &+ i &* 7817) % Int(groesse.height))
                let helligkeit = CGFloat((saat &+ i &* 41) % 100) / 100.0
                UIColor(white: helligkeit, alpha: 0.10).setFill()
                kontext.fill(CGRect(x: x, y: y, width: 4, height: 4))
            }

            // Fuge oder Kante, damit das Bild räumlich wirkt
            let fugeY = CGFloat(220 + saat % 420)
            let neigung = CGFloat(saat % 60) - 30
            UIColor(white: 0.30, alpha: 0.30).setStroke()
            let fuge = UIBezierPath()
            fuge.move(to: CGPoint(x: 0, y: fugeY))
            fuge.addLine(to: CGPoint(x: groesse.width, y: fugeY + neigung))
            fuge.lineWidth = 9
            fuge.stroke()
            UIColor(white: 1, alpha: 0.30).setStroke()
            let glanz = UIBezierPath()
            glanz.move(to: CGPoint(x: 0, y: fugeY + 8))
            glanz.addLine(to: CGPoint(x: groesse.width, y: fugeY + neigung + 8))
            glanz.lineWidth = 3
            glanz.stroke()

            // Der «Mangel»: ein Riss mit Schattenkante, damit er sichtbar ist
            var punkte = [CGPoint(x: CGFloat(180 + saat % 260), y: fugeY - 190)]
            for schritt in 1...11 {
                let letzter = punkte[punkte.count - 1]
                punkte.append(CGPoint(
                    x: letzter.x + CGFloat(48 + (saat &+ schritt &* 131) % 62),
                    y: letzter.y + CGFloat((saat &+ schritt &* 271) % 96) - 40))
            }
            for (farbe, breite, versatz) in [(UIColor(white: 1, alpha: 0.35), CGFloat(5), CGFloat(3)),
                                             (UIColor(white: 0.12, alpha: 0.65), CGFloat(6), CGFloat(0))] {
                farbe.setStroke()
                let pfad = UIBezierPath()
                pfad.move(to: CGPoint(x: punkte[0].x, y: punkte[0].y + versatz))
                for punkt in punkte.dropFirst() {
                    pfad.addLine(to: CGPoint(x: punkt.x, y: punkt.y + versatz))
                }
                pfad.lineWidth = breite
                pfad.lineJoinStyle = .round
                pfad.stroke()
            }

            // Leichte Abdunklung an den Rändern — wirkt wie eine echte Aufnahme
            if let rand = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [UIColor(white: 0, alpha: 0).cgColor,
                                              UIColor(white: 0, alpha: 0.28).cgColor] as CFArray,
                                     locations: [0.55, 1]) {
                kontext.drawRadialGradient(
                    rand,
                    startCenter: CGPoint(x: groesse.width / 2, y: groesse.height / 2),
                    startRadius: 0,
                    endCenter: CGPoint(x: groesse.width / 2, y: groesse.height / 2),
                    endRadius: groesse.width * 0.72,
                    options: [])
            }
        }
    }
}
