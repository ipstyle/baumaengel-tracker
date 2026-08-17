import SwiftUI
import SwiftData

/// Mängelliste eines Raums, mit Filter offen/behoben.
struct RaumDetailView: View {

    @Bindable var raum: Raum
    @Environment(\.modelContext) private var kontext

    @AppStorage("statusfilter") private var filterRoh = Statusfilter.alle.rawValue
    @State private var neuerMangel = false
    @State private var zuBearbeiten: Mangel?

    private var filter: Statusfilter {
        Statusfilter(rawValue: filterRoh) ?? .alle
    }

    private var sichtbar: [Mangel] {
        raum.maengelSortiert.filter(filter.passt)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $filterRoh) {
                ForEach(Statusfilter.allCases) { wahl in
                    Text(wahl.beschriftung).tag(wahl.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            if sichtbar.isEmpty {
                LeerZustand(
                    symbol: raum.anzahlMaengel == 0 ? "checklist" : "line.3.horizontal.decrease.circle",
                    titel: raum.anzahlMaengel == 0 ? "Noch kein Mangel" : "Nichts in dieser Auswahl",
                    text: raum.anzahlMaengel == 0
                        ? "Erfasse den ersten Mangel — Titel, Notiz und ein Foto genügen."
                        : "Wechsle den Filter, um die übrigen Einträge zu sehen.",
                    knopf: raum.anzahlMaengel == 0 ? "Mangel erfassen" : nil,
                    aktion: raum.anzahlMaengel == 0 ? { neuerMangel = true } : nil)
            } else {
                List {
                    ForEach(Array(sichtbar.enumerated()), id: \.element.id) { paar in
                        Button {
                            zuBearbeiten = paar.element
                        } label: {
                            MangelZeile(nummer: nummer(fuer: paar.element), mangel: paar.element)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            Button {
                                paar.element.setzeBehoben(!paar.element.behoben)
                            } label: {
                                Label(paar.element.behoben ? "Offen" : "Behoben",
                                      systemImage: paar.element.behoben ? "arrow.uturn.backward" : "checkmark")
                            }
                            .tint(paar.element.behoben ? .orange : .green)
                        }
                    }
                    .onDelete(perform: loeschen)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(raum.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    neuerMangel = true
                } label: {
                    Label("Mangel erfassen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $neuerMangel) {
            MangelEditorView(mangel: nil) { entwurf in
                let mangel = Mangel(titel: entwurf.titel, notiz: entwurf.notiz)
                entwurf.uebertragen(auf: mangel)
                mangel.raum = raum
                kontext.insert(mangel)
            }
        }
        .sheet(item: $zuBearbeiten) { mangel in
            MangelEditorView(mangel: mangel) { entwurf in
                entwurf.uebertragen(auf: mangel)
            }
        }
    }

    /// Fortlaufende Nummer innerhalb des Raums — unabhängig vom Filter.
    private func nummer(fuer mangel: Mangel) -> Int {
        (raum.maengelSortiert.firstIndex(where: { $0.id == mangel.id }) ?? 0) + 1
    }

    private func loeschen(_ indizes: IndexSet) {
        for index in indizes {
            let mangel = sichtbar[index]
            Fotospeicher.loeschen(mangel.fotoNamen)
            kontext.delete(mangel)
        }
    }
}

private struct MangelZeile: View {
    let nummer: Int
    let mangel: Mangel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let erstes = mangel.fotoNamen.first {
                FotoVorschau(name: erstes, kante: 56)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemFill))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(nummer).")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(mangel.titel)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                }
                if !mangel.notiz.isEmpty {
                    Text(mangel.notiz)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    StatusBadge(behoben: mangel.behoben, ueberfaellig: mangel.fristUeberschritten)
                    if mangel.fotoNamen.count > 1 {
                        Label("\(mangel.fotoNamen.count)", systemImage: "photo.on.rectangle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let frist = mangel.frist, !mangel.behoben {
                        Text("bis \(frist.kurzDatum)")
                            .font(.caption2)
                            .foregroundStyle(mangel.fristUeberschritten ? .red : .secondary)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
