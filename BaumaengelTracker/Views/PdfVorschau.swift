import SwiftUI
import PDFKit

/// Zeigt das fertige Protokoll und bietet es zum Teilen oder Sichern an.
struct PdfVorschau: View {

    let adresse: URL
    let titel: String

    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            PdfFlaeche(adresse: adresse)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Protokoll")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fertig") { schliessen() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: adresse) {
                            Label("Teilen", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
        .tint(.marke)
    }
}

private struct PdfFlaeche: UIViewRepresentable {
    let adresse: URL

    func makeUIView(context: Context) -> PDFView {
        let ansicht = PDFView()
        ansicht.autoScales = true
        ansicht.displayMode = .singlePageContinuous
        ansicht.displayDirection = .vertical
        ansicht.backgroundColor = .systemGroupedBackground
        ansicht.document = PDFDocument(url: adresse)
        return ansicht
    }

    func updateUIView(_ ansicht: PDFView, context: Context) {
        if ansicht.document?.documentURL != adresse {
            ansicht.document = PDFDocument(url: adresse)
        }
    }
}
