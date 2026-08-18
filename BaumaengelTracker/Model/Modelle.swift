import Foundation
import SwiftData

// Drei Ebenen: ein Projekt (das Objekt) enthält Räume, ein Raum enthält Mängel.
// Fotos liegen als JPEG im Documents-Ordner; hier stehen nur die Dateinamen.

@Model
final class Projekt {
    var name: String = ""
    var adresse: String = ""
    var erstelltAm: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Raum.projekt)
    var raeume: [Raum]? = []

    init(name: String, adresse: String = "", erstelltAm: Date = .now) {
        self.name = name
        self.adresse = adresse
        self.erstelltAm = erstelltAm
        self.raeume = []
    }

    var raeumeSortiert: [Raum] {
        (raeume ?? []).sorted { $0.reihenfolge < $1.reihenfolge }
    }

    var alleMaengel: [Mangel] {
        raeumeSortiert.flatMap(\.maengelSortiert)
    }

    var anzahlMaengel: Int { alleMaengel.count }
    var anzahlOffen: Int { alleMaengel.filter { !$0.behoben }.count }
    var anzahlBehoben: Int { anzahlMaengel - anzahlOffen }
}

@Model
final class Raum {
    var name: String = ""
    var reihenfolge: Int = 0
    var projekt: Projekt?

    @Relationship(deleteRule: .cascade, inverse: \Mangel.raum)
    var maengel: [Mangel]? = []

    init(name: String, reihenfolge: Int) {
        self.name = name
        self.reihenfolge = reihenfolge
        self.maengel = []
    }

    var maengelSortiert: [Mangel] {
        (maengel ?? []).sorted { $0.erfasstAm < $1.erfasstAm }
    }

    var anzahlMaengel: Int { maengelSortiert.count }
    var anzahlOffen: Int { maengelSortiert.filter { !$0.behoben }.count }
}

@Model
final class Mangel {
    var titel: String = ""
    var notiz: String = ""
    var behoben: Bool = false
    var erfasstAm: Date = Date.now
    var behobenAm: Date?
    var frist: Date?
    var fotoNamen: [String] = []
    var raum: Raum?

    init(titel: String, notiz: String = "", erfasstAm: Date = .now) {
        self.titel = titel
        self.notiz = notiz
        self.erfasstAm = erfasstAm
        self.fotoNamen = []
    }

    /// Setzt den Status und führt das Behoben-Datum gleich mit.
    func setzeBehoben(_ wert: Bool) {
        guard wert != behoben else { return }
        behoben = wert
        behobenAm = wert ? .now : nil
    }

    var fristUeberschritten: Bool {
        guard let frist, !behoben else { return false }
        return frist < Calendar.current.startOfDay(for: .now)
    }
}

enum Statusfilter: String, CaseIterable, Identifiable {
    case alle, offen, behoben

    var id: String { rawValue }

    var beschriftung: String {
        switch self {
        case .alle: return "Alle"
        case .offen: return "Offen"
        case .behoben: return "Behoben"
        }
    }

    func passt(_ mangel: Mangel) -> Bool {
        switch self {
        case .alle: return true
        case .offen: return !mangel.behoben
        case .behoben: return mangel.behoben
        }
    }
}

extension Date {
    var kurzDatum: String {
        formatted(.dateTime.day(.twoDigits).month(.twoDigits).year())
    }
}

/// Vorlage für den Knopf «Standardräume hinzufügen».
let standardRaeume = ["Küche", "Wohnzimmer", "Bad1", "Bad2",
                      "Reduit", "Keller", "Flur", "Zimmer1"]

/// Deutscher Plural von Hand — zuverlässiger als automatische Beugung.
func maengelText(_ anzahl: Int) -> String {
    anzahl == 1 ? "1 Mangel" : "\(anzahl) Mängel"
}

func raeumeText(_ anzahl: Int) -> String {
    anzahl == 1 ? "1 Raum" : "\(anzahl) Räume"
}
