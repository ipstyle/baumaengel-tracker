import Foundation

/// Abzug der Modelldaten für den PDF-Satz.
///
/// SwiftData-Objekte gehören dem Hauptstrang. Der Abzug wird dort gezogen und
/// ist danach unabhängig — so kann das Dokument im Hintergrund entstehen, ohne
/// dass die Oberfläche steht.
struct ProtokollDaten: Sendable {
    let name: String
    let adresse: String
    let anzahlMaengel: Int
    let anzahlOffen: Int
    let anzahlBehoben: Int
    let raeume: [RaumDaten]

    @MainActor
    init(_ projekt: Projekt) {
        name = projekt.name
        adresse = projekt.adresse
        anzahlMaengel = projekt.anzahlMaengel
        anzahlOffen = projekt.anzahlOffen
        anzahlBehoben = projekt.anzahlBehoben
        raeume = projekt.raeumeSortiert
            .filter { !$0.maengelSortiert.isEmpty }
            .map(RaumDaten.init)
    }
}

struct RaumDaten: Sendable {
    let name: String
    let anzahlMaengel: Int
    let anzahlOffen: Int
    let maengel: [MangelDaten]

    @MainActor
    init(_ raum: Raum) {
        name = raum.name
        anzahlMaengel = raum.anzahlMaengel
        anzahlOffen = raum.anzahlOffen
        maengel = raum.maengelSortiert.map(MangelDaten.init)
    }
}

struct MangelDaten: Sendable {
    let titel: String
    let notiz: String
    let behoben: Bool
    let ueberfaellig: Bool
    let erfasstAm: Date
    let behobenAm: Date?
    let frist: Date?
    let fotoNamen: [String]

    @MainActor
    init(_ mangel: Mangel) {
        titel = mangel.titel
        notiz = mangel.notiz
        behoben = mangel.behoben
        ueberfaellig = mangel.fristUeberschritten
        erfasstAm = mangel.erfasstAm
        behobenAm = mangel.behobenAm
        frist = mangel.frist
        fotoNamen = mangel.fotoNamen
    }
}
