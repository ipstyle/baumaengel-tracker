import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Darstellung, Sicherung und Angaben zur App — bewusst ein einziges Blatt.
struct EinstellungenView: View {

    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Projekt.erstelltAm, order: .reverse) private var projekte: [Projekt]

    @AppStorage(Schluessel.erscheinungsbild) private var bildRoh = Erscheinungsbild.system.rawValue
    @AppStorage(Schluessel.kompakt) private var kompakt = false

    @State private var laeuft = false
    @State private var fertigeSicherung: DateiZumTeilen?
    @State private var importOffen = false
    @State private var gelesen: SicherungsDatei?
    @State private var ersetzenNachfrage = false
    @State private var fehlertext: String?
    @State private var meldung: String?

    private let quellcode = URL(string: "https://github.com/ipstyle/baumaengel-tracker")!
    private let datenschutz = URL(string: "https://github.com/ipstyle/baumaengel-tracker/blob/main/PRIVACY.md")!

    var body: some View {
        NavigationStack {
            formular
                .navigationTitle("Einstellungen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { schliessen() }
                    }
                }
        }
        .tint(.marke)
        .fileImporter(isPresented: $importOffen,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false,
                      onCompletion: einlesen)
        .sheet(item: $fertigeSicherung) { datei in
            SicherungFertig(datei: datei)
        }
        .confirmationDialog(uebersicht, isPresented: auswahlGezeigt, titleVisibility: .visible) {
            Button("Anfügen") { einspielen(.anfuegen) }
            Button("Alles ersetzen", role: .destructive) { ersetzenNachfrage = true }
            Button("Abbrechen", role: .cancel) { gelesen = nil }
        } message: {
            Text("«Anfügen» lässt die vorhandenen Projekte unberührt. «Alles ersetzen» löscht sie vorher.")
        }
        .alert("Wirklich alles ersetzen?", isPresented: $ersetzenNachfrage) {
            Button("Ersetzen", role: .destructive) { einspielen(.ersetzen) }
            Button("Abbrechen", role: .cancel) { gelesen = nil }
        } message: {
            Text("Alle bestehenden Projekte, Mängel und Fotos werden gelöscht. Das lässt sich nicht rückgängig machen.")
        }
        .alert("Das hat nicht geklappt", isPresented: fehlerGezeigt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fehlertext ?? "")
        }
        .alert("Sicherung eingelesen", isPresented: meldungGezeigt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(meldung ?? "")
        }
    }

    // Bindungen einzeln benannt — das entlastet die Typprüfung spürbar.
    private var auswahlGezeigt: Binding<Bool> {
        Binding(get: { gelesen != nil && !ersetzenNachfrage },
                set: { if !$0 { gelesen = nil } })
    }

    private var fehlerGezeigt: Binding<Bool> {
        Binding(get: { fehlertext != nil }, set: { if !$0 { fehlertext = nil } })
    }

    private var meldungGezeigt: Binding<Bool> {
        Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })
    }

    // Die Ansicht ist bewusst in Stücke geteilt: als eine einzige Kette
    // scheitert der Übersetzer an der Typprüfung.
    private var formular: some View {
        Form {
            darstellung
            daten
            ueber
        }
    }

    private var darstellung: some View {
        Section {
            Picker("Erscheinungsbild", selection: $bildRoh) {
                ForEach(Erscheinungsbild.allCases) { wahl in
                    Text(wahl.beschriftung).tag(wahl.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Kompakte Liste", isOn: $kompakt)
        } header: {
            Text("Darstellung")
        } footer: {
            Text("Kompakt zeigt mehr Mängel auf einen Blick: kleinere Vorschau, ohne Notizzeile.")
        }
    }

    private var daten: some View {
        Section {
            Button {
                exportieren()
            } label: {
                HStack {
                    Label("Sicherung erstellen", systemImage: "square.and.arrow.up")
                    Spacer()
                    if laeuft { ProgressView() }
                }
            }
            .disabled(projekte.isEmpty || laeuft)

            Button {
                importOffen = true
            } label: {
                Label("Sicherung einlesen", systemImage: "square.and.arrow.down")
            }
            .disabled(laeuft)
        } header: {
            Text("Daten")
        } footer: {
            Text("Eine Sicherung enthält alle Projekte, Räume, Mängel und Fotos in einer einzigen Datei. Die Fotos werden dabei auf 1600 px verkleinert, damit die Datei versendbar bleibt.")
        }
    }

    private var ueber: some View {
        Section {
            LabeledContent("Version", value: "\(version) (\(build))")
            Link(destination: quellcode) {
                Label("Quellcode auf GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Link(destination: datenschutz) {
                Label("Datenschutz", systemImage: "hand.raised")
            }
            LabeledContent("Lizenz", value: "MIT")
            LabeledContent("Copyright", value: "© 2026 Albert Frick")
        } header: {
            Text("Über")
        } footer: {
            Text("Kein Konto, keine Werbung, keine Analyse. Die App selbst stellt keine Netzwerkverbindung her — die beiden Verweise oben öffnen den Browser.")
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var uebersicht: String {
        guard let gelesen else { return "Sicherung einlesen" }
        let projekteText = gelesen.projekte.count == 1 ? "1 Projekt" : "\(gelesen.projekte.count) Projekte"
        return "\(projekteText) · \(maengelText(gelesen.anzahlMaengel)) · \(gelesen.anzahlFotos) Fotos"
    }

    // MARK: - Wege

    private func exportieren() {
        laeuft = true
        let abzug = Sicherung.abzug(aus: projekte)
        Task {
            do {
                let adresse = try await Task.detached(priority: .userInitiated) {
                    try Sicherung.schreiben(abzug)
                }.value
                fertigeSicherung = DateiZumTeilen(adresse: adresse)
            } catch {
                fehlertext = error.localizedDescription
            }
            laeuft = false
        }
    }

    private func einlesen(_ ergebnis: Result<[URL], Error>) {
        switch ergebnis {
        case .success(let adressen):
            guard let adresse = adressen.first else { return }
            do {
                gelesen = try Sicherung.lesen(adresse)
            } catch {
                fehlertext = error.localizedDescription
            }
        case .failure(let fehler):
            fehlertext = fehler.localizedDescription
        }
    }

    private func einspielen(_ modus: Sicherung.Modus) {
        guard let datei = gelesen else { return }
        Sicherung.einspielen(datei, modus: modus, in: kontext)
        gelesen = nil
        ersetzenNachfrage = false
        meldung = modus == .ersetzen
            ? "Der bisherige Bestand wurde ersetzt: \(maengelText(datei.anzahlMaengel)) in \(datei.projekte.count) Projekten."
            : "\(maengelText(datei.anzahlMaengel)) in \(datei.projekte.count) Projekten hinzugefügt."
    }
}

/// Zeigt die fertige Sicherung mit ihrer Grösse und bietet sie zum Teilen an.
private struct SicherungFertig: View {
    let datei: DateiZumTeilen
    @Environment(\.dismiss) private var schliessen

    private var groesse: String {
        let bytes = (try? datei.adresse.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.statusBehoben)
                Text("Sicherung bereit")
                    .font(.headline)
                Text("\(datei.adresse.lastPathComponent)\n\(groesse)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ShareLink(item: datei.adresse) {
                    Label("Sichern oder senden", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                Text("Lege die Datei dort ab, wo du sie wiederfindest — in den Dateien, in der Cloud oder per Mail an dich selbst.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
        .presentationDetents([.medium])
        .tint(.marke)
    }
}
