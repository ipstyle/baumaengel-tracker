import SwiftUI
import SwiftData

/// Räume eines Projekts, Fortschritt und der Weg zum PDF.
struct ProjektDetailView: View {

    @Bindable var projekt: Projekt
    @Environment(\.modelContext) private var kontext

    @State private var neuerRaum = ""
    @State private var raumAbfrage = false
    @State private var vorlageAbfrage = false
    @State private var pdfDatei: DateiZumTeilen?
    @State private var pdfLaeuft = false
    @State private var fehlertext: String?

    var body: some View {
        List {
            Section {
                Fortschritt(gesamt: projekt.anzahlMaengel, behoben: projekt.anzahlBehoben)
                    .padding(.vertical, 4)
                if !projekt.adresse.isEmpty {
                    LabeledContent("Adresse", value: projekt.adresse)
                        .font(.subheadline)
                }
                LabeledContent("Angelegt", value: projekt.erstelltAm.kurzDatum)
                    .font(.subheadline)
            }

            Section("Räume") {
                if projekt.raeumeSortiert.isEmpty {
                    Text("Noch kein Raum. Lege einen an — Küche, Bad, Wohnzimmer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(projekt.raeumeSortiert) { raum in
                    NavigationLink(value: raum) {
                        RaumZeile(raum: raum)
                    }
                }
                .onDelete(perform: raeumeLoeschen)
                .onMove(perform: raeumeVerschieben)

                Button {
                    neuerRaum = ""
                    raumAbfrage = true
                } label: {
                    Label("Raum hinzufügen", systemImage: "plus.circle.fill")
                }

                if !fehlendeStandardraeume.isEmpty {
                    Button {
                        vorlageAbfrage = true
                    } label: {
                        Label("Standardräume hinzufügen", systemImage: "square.grid.2x2")
                    }
                }
            }

            Section {
                Button {
                    pdfErstellen()
                } label: {
                    HStack {
                        Label("PDF-Protokoll erstellen", systemImage: "doc.richtext")
                        Spacer()
                        if pdfLaeuft { ProgressView() }
                    }
                }
                .disabled(projekt.anzahlMaengel == 0 || pdfLaeuft)
            } footer: {
                Text(projekt.anzahlMaengel == 0
                     ? "Sobald der erste Mangel erfasst ist, lässt sich das Protokoll erstellen."
                     : "Enthält alle Räume und Mängel mit Fotos, Notizen und Status.")
            }
        }
        .navigationTitle(projekt.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Raum.self) { raum in
            RaumDetailView(raum: raum)
        }
        .toolbar { EditButton() }
        .confirmationDialog("Standardräume hinzufügen",
                            isPresented: $vorlageAbfrage, titleVisibility: .visible) {
            Button("\(fehlendeStandardraeume.count) Räume anlegen") { vorlageAnwenden() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(fehlendeStandardraeume.joined(separator: ", ")
                 + "\n\nBereits vorhandene Räume werden übersprungen. Umbenennen und sortieren kannst du danach.")
        }
        .alert("Neuer Raum", isPresented: $raumAbfrage) {
            TextField("Name, z. B. Küche", text: $neuerRaum)
            Button("Abbrechen", role: .cancel) {}
            Button("Anlegen") { raumAnlegen() }
        }
        .alert("Das PDF liess sich nicht erstellen",
               isPresented: Binding(get: { fehlertext != nil },
                                    set: { if !$0 { fehlertext = nil } })) {
            Button("OK", role: .cancel) { fehlertext = nil }
        } message: {
            Text(fehlertext ?? "")
        }
        .sheet(item: $pdfDatei) { datei in
            PdfVorschau(adresse: datei.adresse, titel: projekt.name)
        }
    }

    /// Nur, was es noch nicht gibt — der Knopf darf nichts doppelt anlegen.
    private var fehlendeStandardraeume: [String] {
        let vorhanden = Set(projekt.raeumeSortiert.map { $0.name.lowercased() })
        return standardRaeume.filter { !vorhanden.contains($0.lowercased()) }
    }

    private func vorlageAnwenden() {
        var naechste = (projekt.raeumeSortiert.last?.reihenfolge ?? -1) + 1
        for name in fehlendeStandardraeume {
            let raum = Raum(name: name, reihenfolge: naechste)
            raum.projekt = projekt
            kontext.insert(raum)
            naechste += 1
        }
    }

    private func raumAnlegen() {
        let name = neuerRaum.trimmed
        guard !name.isEmpty else { return }
        let naechste = (projekt.raeumeSortiert.last?.reihenfolge ?? -1) + 1
        let raum = Raum(name: name, reihenfolge: naechste)
        raum.projekt = projekt
        kontext.insert(raum)
    }

    private func raeumeLoeschen(_ indizes: IndexSet) {
        let sortiert = projekt.raeumeSortiert
        for index in indizes {
            let raum = sortiert[index]
            Fotospeicher.loeschen(raum.maengelSortiert.flatMap(\.fotoNamen))
            kontext.delete(raum)
        }
    }

    private func raeumeVerschieben(_ quelle: IndexSet, _ ziel: Int) {
        var sortiert = projekt.raeumeSortiert
        sortiert.move(fromOffsets: quelle, toOffset: ziel)
        for (index, raum) in sortiert.enumerated() {
            raum.reihenfolge = index
        }
    }

    private func pdfErstellen() {
        pdfLaeuft = true
        // Abzug auf dem Hauptstrang ziehen, satz und Bildaufbereitung daneben —
        // bei 60 Mängeln sind das drei Sekunden, die sonst die Oberfläche anhalten.
        let abzug = ProtokollDaten(projekt)
        Task {
            do {
                let adresse = try await Task.detached(priority: .userInitiated) {
                    try PdfProtokoll.erstellen(aus: abzug)
                }.value
                pdfDatei = DateiZumTeilen(adresse: adresse)
            } catch {
                fehlertext = error.localizedDescription
            }
            pdfLaeuft = false
        }
    }
}

private struct RaumZeile: View {
    let raum: Raum

    var body: some View {
        HStack(spacing: 12) {
            SymbolFeld(symbol: raumSymbol(raum.name))
            VStack(alignment: .leading, spacing: 3) {
                Text(raum.name)
                Text(raum.anzahlMaengel == 0
                     ? "keine Mängel"
                     : "\(maengelText(raum.anzahlMaengel)) · \(raum.anzahlOffen) offen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if raum.anzahlOffen > 0 {
                Text("\(raum.anzahlOffen)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.statusOffen.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.statusOffen)
            }
        }
    }
}
