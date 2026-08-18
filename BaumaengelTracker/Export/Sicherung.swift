import Foundation
import SwiftData

// Eine Sicherung ist eine einzige JSON-Datei mit allem darin — Projekte, Räume,
// Mängel und die Fotos. Kein Zusatzpaket, keine zweite Datei, die verloren gehen
// kann. Die Fotos werden dabei auf 1600 px verkleinert; das reicht als Beleg und
// hält die Datei versendbar.

struct SicherungsDatei: Codable, Sendable {
    var format: Int = 1
    var erstelltAm: Date
    var projekte: [SicherungProjekt]

    var anzahlMaengel: Int { projekte.flatMap(\.raeume).flatMap(\.maengel).count }
    var anzahlFotos: Int {
        projekte.flatMap(\.raeume).flatMap(\.maengel).reduce(0) { $0 + $1.fotos.count }
    }
}

struct SicherungProjekt: Codable, Sendable {
    var name: String
    var adresse: String
    var erstelltAm: Date
    var raeume: [SicherungRaum]
}

struct SicherungRaum: Codable, Sendable {
    var name: String
    var reihenfolge: Int
    var maengel: [SicherungMangel]
}

struct SicherungMangel: Codable, Sendable {
    var titel: String
    var notiz: String
    var behoben: Bool
    var erfasstAm: Date
    var behobenAm: Date?
    var frist: Date?
    var fotos: [Data]
}

enum Sicherung {

    enum Modus: String, Identifiable {
        case anfuegen, ersetzen
        var id: String { rawValue }
    }

    enum Fehler: LocalizedError {
        case schreiben
        case lesen
        case format

        var errorDescription: String? {
            switch self {
            case .schreiben:
                return "Die Sicherung konnte nicht abgelegt werden. Prüfe den freien Speicher."
            case .lesen:
                return "Die Datei liess sich nicht öffnen. Wähle sie nochmals aus."
            case .format:
                return "Das ist keine Sicherung dieser App — oder sie stammt aus einer neueren Fassung."
            }
        }
    }

    // MARK: - Ausgeben

    /// Abzug auf dem Hauptstrang; das Codieren läuft danach daneben.
    @MainActor
    static func abzug(aus projekte: [Projekt]) -> SicherungsDatei {
        SicherungsDatei(
            erstelltAm: .now,
            projekte: projekte.map { projekt in
                SicherungProjekt(
                    name: projekt.name,
                    adresse: projekt.adresse,
                    erstelltAm: projekt.erstelltAm,
                    raeume: projekt.raeumeSortiert.map { raum in
                        SicherungRaum(
                            name: raum.name,
                            reihenfolge: raum.reihenfolge,
                            maengel: raum.maengelSortiert.map { mangel in
                                SicherungMangel(
                                    titel: mangel.titel,
                                    notiz: mangel.notiz,
                                    behoben: mangel.behoben,
                                    erfasstAm: mangel.erfasstAm,
                                    behobenAm: mangel.behobenAm,
                                    frist: mangel.frist,
                                    fotos: mangel.fotoNamen.compactMap(Fotospeicher.fuerSicherung))
                            })
                    })
            })
    }

    static func schreiben(_ datei: SicherungsDatei) throws -> URL {
        let codierer = JSONEncoder()
        codierer.dateEncodingStrategy = .iso8601
        codierer.outputFormatting = .withoutEscapingSlashes
        guard let bytes = try? codierer.encode(datei), !bytes.isEmpty else {
            throw Fehler.schreiben
        }
        let datum = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent("Baumängel-Sicherung \(datum).json")
        do {
            try bytes.write(to: ziel, options: .atomic)
        } catch {
            throw Fehler.schreiben
        }
        return ziel
    }

    // MARK: - Einlesen

    static func lesen(_ adresse: URL) throws -> SicherungsDatei {
        // Dateien aus der Dateien-App liegen ausserhalb des App-Ordners; ohne
        // diese Klammer verweigert das System den Zugriff.
        let geschuetzt = adresse.startAccessingSecurityScopedResource()
        defer { if geschuetzt { adresse.stopAccessingSecurityScopedResource() } }

        guard let bytes = try? Data(contentsOf: adresse) else { throw Fehler.lesen }
        let leser = JSONDecoder()
        leser.dateDecodingStrategy = .iso8601
        guard let datei = try? leser.decode(SicherungsDatei.self, from: bytes) else {
            throw Fehler.format
        }
        guard datei.format <= 1 else { throw Fehler.format }
        return datei
    }

    @MainActor
    static func einspielen(_ datei: SicherungsDatei, modus: Modus, in kontext: ModelContext) {
        if modus == .ersetzen {
            let vorhandene = (try? kontext.fetch(FetchDescriptor<Projekt>())) ?? []
            for projekt in vorhandene {
                Fotospeicher.loeschen(projekt.alleMaengel.flatMap(\.fotoNamen))
                kontext.delete(projekt)
            }
        }

        for eintrag in datei.projekte {
            let projekt = Projekt(name: eintrag.name,
                                  adresse: eintrag.adresse,
                                  erstelltAm: eintrag.erstelltAm)
            kontext.insert(projekt)

            for raumEintrag in eintrag.raeume.sorted(by: { $0.reihenfolge < $1.reihenfolge }) {
                let raum = Raum(name: raumEintrag.name, reihenfolge: raumEintrag.reihenfolge)
                raum.projekt = projekt
                kontext.insert(raum)

                for mangelEintrag in raumEintrag.maengel {
                    let mangel = Mangel(titel: mangelEintrag.titel,
                                        notiz: mangelEintrag.notiz,
                                        erfasstAm: mangelEintrag.erfasstAm)
                    mangel.behoben = mangelEintrag.behoben
                    mangel.behobenAm = mangelEintrag.behobenAm
                    mangel.frist = mangelEintrag.frist
                    // Jedes Bild bekommt einen neuen Namen — eine Sicherung kann
                    // damit niemals ein bestehendes Foto überschreiben.
                    mangel.fotoNamen = mangelEintrag.fotos.compactMap(Fotospeicher.ablegen)
                    mangel.raum = raum
                    kontext.insert(mangel)
                }
            }
        }
        try? kontext.save()
    }
}
