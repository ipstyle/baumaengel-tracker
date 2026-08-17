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
            }
            let maengel = (try? container.mainContext.fetch(FetchDescriptor<Mangel>())) ?? []
            Fotospeicher.aufraeumen(bekannt: Set(maengel.flatMap(\.fotoNamen)))
        }
    }

    var body: some Scene {
        WindowGroup {
            ProjekteView()
        }
        .modelContainer(container)
    }
}
