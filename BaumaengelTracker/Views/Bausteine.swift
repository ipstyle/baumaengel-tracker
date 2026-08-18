import SwiftUI

/// Kleiner Träger, damit `.sheet(item:)` eine Identität hat — für das PDF
/// wie für die Sicherungsdatei.
struct DateiZumTeilen: Identifiable {
    let id = UUID()
    let adresse: URL
}

extension Color {
    /// Die Akzentfarbe der App. Blätter erben `accentColor` nicht zuverlässig,
    /// darum wird sie an jedem Blatt ausdrücklich als `tint` gesetzt.
    static let marke = Color("AkzentFarbe")
    static let statusOffen = Color(red: 0.85, green: 0.42, blue: 0.10)
    static let statusBehoben = Color(red: 0.16, green: 0.55, blue: 0.31)
}

/// Symbol in einem getönten Feld — gibt den Listen ihren grafischen Halt.
struct SymbolFeld: View {
    let symbol: String
    var farbe: Color = .marke
    var kante: CGFloat = 38

    var body: some View {
        RoundedRectangle(cornerRadius: kante * 0.28, style: .continuous)
            .fill(farbe.opacity(0.14))
            .frame(width: kante, height: kante)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: kante * 0.46, weight: .medium))
                    .foregroundStyle(farbe))
    }
}

/// Kleine Statusmarke — dieselbe Sprache wie im PDF.
struct StatusBadge: View {
    let behoben: Bool
    var ueberfaellig: Bool = false

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(farbe.opacity(0.15), in: Capsule())
            .foregroundStyle(farbe)
    }

    private var text: String {
        if behoben { return "Behoben" }
        return ueberfaellig ? "Überfällig" : "Offen"
    }

    private var symbol: String {
        if behoben { return "checkmark.circle.fill" }
        return ueberfaellig ? "exclamationmark.triangle.fill" : "circle.dotted"
    }

    private var farbe: Color {
        if behoben { return .statusBehoben }
        return ueberfaellig ? .red : .statusOffen
    }
}

/// Wird gezeigt, solange eine Liste leer ist — mit dem Knopf, der weiterhilft.
struct LeerZustand: View {
    let symbol: String
    let titel: String
    let text: String
    var knopf: String?
    var aktion: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text(titel)
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if let knopf, let aktion {
                Button(knopf, action: aktion)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

/// Fortschrittsbalken «3 von 7 behoben».
struct Fortschritt: View {
    let gesamt: Int
    let behoben: Int

    private var anteil: Double {
        gesamt == 0 ? 0 : Double(behoben) / Double(gesamt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(maengelText(gesamt))
                Spacer()
                Text("\(behoben) behoben")
                    .foregroundStyle(behoben == gesamt && gesamt > 0 ? Color.statusBehoben : .secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            GeometryReader { raum in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                    Capsule()
                        .fill(Color.statusBehoben)
                        .frame(width: raum.size.width * anteil)
                }
            }
            .frame(height: 6)
        }
    }
}

/// Quadratische Vorschau eines gespeicherten Fotos.
struct FotoVorschau: View {
    let name: String
    var kante: CGFloat = 64

    var body: some View {
        Group {
            if let bild = Fotospeicher.vorschau(name, kante: kante * 3) {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.secondarySystemFill)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
        }
        .frame(width: kante, height: kante)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
