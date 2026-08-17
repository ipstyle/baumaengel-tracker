import SwiftUI

/// Fotos in voller Grösse durchblättern und einzeln entfernen.
struct FotoGalerieView: View {

    let namen: [String]
    let start: Int
    let entfernen: (String) -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var index = 0
    @State private var nachfrage = false

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                ForEach(Array(namen.enumerated()), id: \.element) { paar in
                    Group {
                        if let bild = Fotospeicher.bild(paar.element) {
                            Image(uiImage: bild)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(paar.offset)
                }
            }
            .tabViewStyle(.page)
            .background(Color.black)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("\(min(index + 1, namen.count)) von \(namen.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { schliessen() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        nachfrage = true
                    } label: {
                        Label("Foto löschen", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog("Dieses Foto löschen?", isPresented: $nachfrage, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    guard namen.indices.contains(index) else { return }
                    entfernen(namen[index])
                    schliessen()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
        .tint(.marke)
        .onAppear { index = start }
    }
}
