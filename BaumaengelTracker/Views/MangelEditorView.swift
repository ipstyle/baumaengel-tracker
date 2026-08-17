import SwiftUI
import PhotosUI
import AVFoundation

/// Zwischenstand beim Bearbeiten — erst beim Sichern landet er im Modell.
struct MangelEntwurf {
    var titel = ""
    var notiz = ""
    var behoben = false
    var behobenAm: Date?
    var mitFrist = false
    var frist = Date.now
    var fotoNamen: [String] = []

    init() {}

    init(_ mangel: Mangel) {
        titel = mangel.titel
        notiz = mangel.notiz
        behoben = mangel.behoben
        behobenAm = mangel.behobenAm
        mitFrist = mangel.frist != nil
        frist = mangel.frist ?? .now
        fotoNamen = mangel.fotoNamen
    }

    func uebertragen(auf mangel: Mangel) {
        mangel.titel = titel
        mangel.notiz = notiz
        mangel.fotoNamen = fotoNamen
        mangel.frist = mitFrist ? frist : nil
        if mangel.behoben != behoben {
            mangel.behoben = behoben
            mangel.behobenAm = behoben ? (behobenAm ?? .now) : nil
        }
    }
}

struct MangelEditorView: View {

    let mangel: Mangel?
    let sichern: (MangelEntwurf) -> Void

    @Environment(\.dismiss) private var schliessen

    @State private var entwurf = MangelEntwurf()
    @State private var urspruenglicheFotos: [String] = []
    @State private var vorbereitet = false
    @State private var kameraOffen = false
    @State private var mediathek: [PhotosPickerItem] = []
    @State private var galerieIndex: Int?
    @State private var kameraHinweis = false
    @FocusState private var imTitel: Bool

    private var kameraVorhanden: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mangel") {
                    TextField("Kurz und eindeutig, z. B. Kratzer in der Fensterbank",
                              text: $entwurf.titel, axis: .vertical)
                        .focused($imTitel)
                    TextField("Notiz (optional)", text: $entwurf.notiz, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Fotos") {
                    fotoZeile
                    HStack(spacing: 12) {
                        if kameraVorhanden {
                            Button {
                                kameraStarten()
                            } label: {
                                Label("Kamera", systemImage: "camera")
                            }
                            .buttonStyle(.bordered)
                        }
                        PhotosPicker(selection: $mediathek, matching: .images, photoLibrary: .shared()) {
                            Label("Aus Fotos", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }

                Section("Status") {
                    Toggle("Behoben", isOn: Binding(
                        get: { entwurf.behoben },
                        set: { neu in
                            entwurf.behoben = neu
                            entwurf.behobenAm = neu ? (entwurf.behobenAm ?? .now) : nil
                        }))
                    if entwurf.behoben, let datum = entwurf.behobenAm {
                        LabeledContent("Behoben am", value: datum.kurzDatum)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Frist setzen", isOn: $entwurf.mitFrist)
                    if entwurf.mitFrist {
                        DatePicker("Frist", selection: $entwurf.frist, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(mangel == nil ? "Neuer Mangel" : "Mangel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { abbrechen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { fertig() }
                        .disabled(entwurf.titel.trimmed.isEmpty)
                }
            }
            .onAppear(perform: vorbereiten)
            .onChange(of: mediathek) { _, neu in
                guard !neu.isEmpty else { return }
                Task { await mediathekUebernehmen(neu) }
            }
            .fullScreenCover(isPresented: $kameraOffen) {
                KameraAufnahme { bild in
                    if let name = Fotospeicher.speichern(bild) {
                        entwurf.fotoNamen.append(name)
                    }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(item: Binding(
                get: { galerieIndex.map { GalerieStart(index: $0) } },
                set: { galerieIndex = $0?.index })) { start in
                FotoGalerieView(namen: entwurf.fotoNamen, start: start.index) { name in
                    entwurf.fotoNamen.removeAll { $0 == name }
                }
            }
            .alert("Kein Zugriff auf die Kamera", isPresented: $kameraHinweis) {
                Button("Einstellungen öffnen") {
                    if let adresse = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(adresse)
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Erlaube den Kamerazugriff in den Einstellungen, oder wähle ein Bild aus der Fotomediathek.")
            }
        }
        // Blätter erben die Akzentfarbe nicht immer — hier ausdrücklich setzen.
        .tint(.marke)
    }

    private var fotoZeile: some View {
        Group {
            if entwurf.fotoNamen.isEmpty {
                Text("Noch kein Foto. Ein Bild sagt im Protokoll mehr als drei Sätze.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(entwurf.fotoNamen.enumerated()), id: \.element) { paar in
                            Button {
                                galerieIndex = paar.offset
                            } label: {
                                FotoVorschau(name: paar.element, kante: 84)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func vorbereiten() {
        guard !vorbereitet else { return }
        vorbereitet = true
        if let mangel {
            entwurf = MangelEntwurf(mangel)
        }
        urspruenglicheFotos = entwurf.fotoNamen
        if mangel == nil { imTitel = true }
    }

    /// Erst fragen, dann öffnen — sonst zeigt die Kamera nur ein schwarzes Bild.
    private func kameraStarten() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            kameraOffen = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { erlaubt in
                DispatchQueue.main.async {
                    if erlaubt { kameraOffen = true } else { kameraHinweis = true }
                }
            }
        default:
            kameraHinweis = true
        }
    }

    private func mediathekUebernehmen(_ auswahl: [PhotosPickerItem]) async {
        for eintrag in auswahl {
            if let daten = try? await eintrag.loadTransferable(type: Data.self),
               let bild = UIImage(data: daten),
               let name = Fotospeicher.speichern(bild) {
                entwurf.fotoNamen.append(name)
            }
        }
        mediathek = []
    }

    private func fertig() {
        entwurf.titel = entwurf.titel.trimmed
        entwurf.notiz = entwurf.notiz.trimmed
        // Fotos, die hier entfernt wurden, gehören auch von der Platte weg.
        let entfernt = urspruenglicheFotos.filter { !entwurf.fotoNamen.contains($0) }
        Fotospeicher.loeschen(entfernt)
        sichern(entwurf)
        schliessen()
    }

    private func abbrechen() {
        // Was in dieser Sitzung dazukam, wird beim Abbrechen wieder weggeräumt.
        let neu = entwurf.fotoNamen.filter { !urspruenglicheFotos.contains($0) }
        Fotospeicher.loeschen(neu)
        schliessen()
    }
}

private struct GalerieStart: Identifiable {
    let index: Int
    var id: Int { index }
}
