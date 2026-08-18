import SwiftUI
import SwiftData

@main
struct BaumaengelTrackerApp: App {

    private let container: ModelContainer

    init() {
        let schema = Schema([Projekt.self, Raum.self, Mangel.self])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            // Lieber ohne gespeicherte Daten starten als abstürzen — die App
            // bleibt bedienbar und der Fehler ist sichtbar statt tödlich.
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }

        MainActor.assumeIsolated {
            if CommandLine.arguments.contains("-seedDemo") {
                Demodaten.anlegen(in: container.mainContext)
            } else if CommandLine.arguments.contains("-seedLast") {
                Demodaten.anlegenGross(in: container.mainContext)
            }
            let maengel = (try? container.mainContext.fetch(FetchDescriptor<Mangel>())) ?? []
            Fotospeicher.aufraeumen(bekannt: Set(maengel.flatMap(\.fotoNamen)))
        }
    }

    var body: some Scene {
        WindowGroup {
            Wurzel()
        }
        .modelContainer(container)
    }
}

/// Sitzt zwischen Fenster und Projektliste, damit die Wahl des Erscheinungsbilds
/// auch für Blätter und die PDF-Vorschau gilt.
private struct Wurzel: View {
    @AppStorage(Schluessel.erscheinungsbild) private var bildRoh = Erscheinungsbild.system.rawValue

    var body: some View {
        ProjekteView()
            .preferredColorScheme(Erscheinungsbild(rawValue: bildRoh)?.farbschema)
    }
}
