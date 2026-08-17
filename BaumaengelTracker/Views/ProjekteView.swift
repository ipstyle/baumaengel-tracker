import SwiftUI
import SwiftData

/// Startbildschirm: alle Objekte, für die ein Protokoll geführt wird.
struct ProjekteView: View {

    @Environment(\.modelContext) private var kontext
    @Query(sort: \Projekt.erstelltAm, order: .reverse) private var projekte: [Projekt]

    @State private var neuesProjekt = false
    @State private var zuBearbeiten: Projekt?

    var body: some View {
        NavigationStack {
            Group {
                if projekte.isEmpty {
                    LeerZustand(
                        symbol: "building.2",
                        titel: "Noch kein Projekt",
                        text: "Lege ein Objekt an — eine Wohnung, ein Haus, eine Baustelle. Darin führst du Räume und deren Mängel.",
                        knopf: "Projekt anlegen",
                        aktion: { neuesProjekt = true })
                } else {
                    liste
                }
            }
            .navigationTitle("Projekte")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        neuesProjekt = true
                    } label: {
                        Label("Projekt anlegen", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $neuesProjekt) {
                ProjektEditor(projekt: nil) { name, adresse in
                    let projekt = Projekt(name: name, adresse: adresse)
                    kontext.insert(projekt)
                }
            }
            .sheet(item: $zuBearbeiten) { projekt in
                ProjektEditor(projekt: projekt) { name, adresse in
                    projekt.name = name
                    projekt.adresse = adresse
                }
            }
        }
        .tint(.marke)
    }

    private var liste: some View {
        List {
            ForEach(projekte) { projekt in
                NavigationLink(value: projekt) {
                    ProjektZeile(projekt: projekt)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        zuBearbeiten = projekt
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: loeschen)
        }
        .navigationDestination(for: Projekt.self) { projekt in
            ProjektDetailView(projekt: projekt)
        }
    }

    private func loeschen(_ indizes: IndexSet) {
        for index in indizes {
            let projekt = projekte[index]
            // Fotos hängen nicht am Store, die müssen von Hand weg.
            Fotospeicher.loeschen(projekt.alleMaengel.flatMap(\.fotoNamen))
            kontext.delete(projekt)
        }
    }
}

private struct ProjektZeile: View {
    let projekt: Projekt

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(projekt.name)
                .font(.headline)
            if !projekt.adresse.isEmpty {
                Text(projekt.adresse)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text(maengelText(projekt.anzahlMaengel))
                if projekt.anzahlOffen > 0 {
                    Text("·")
                    Text("\(projekt.anzahlOffen) offen")
                        .foregroundStyle(Color.statusOffen)
                } else if projekt.anzahlMaengel > 0 {
                    Text("·")
                    Text("alle behoben")
                        .foregroundStyle(Color.statusBehoben)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Blatt zum Anlegen und Bearbeiten — bewusst nur zwei Felder.
struct ProjektEditor: View {
    let projekt: Projekt?
    let sichern: (String, String) -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var name = ""
    @State private var adresse = ""
    @FocusState private var imNamen: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Objekt") {
                    TextField("Name, z. B. Wohnung 3.1", text: $name)
                        .focused($imNamen)
                    TextField("Adresse (optional)", text: $adresse, axis: .vertical)
                }
            }
            .navigationTitle(projekt == nil ? "Neues Projekt" : "Projekt bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        sichern(name.trimmed, adresse.trimmed)
                        schliessen()
                    }
                    .disabled(name.trimmed.isEmpty)
                }
            }
            .onAppear {
                name = projekt?.name ?? ""
                adresse = projekt?.adresse ?? ""
                imNamen = true
            }
        }
        .tint(.marke)
        .presentationDetents([.medium])
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
