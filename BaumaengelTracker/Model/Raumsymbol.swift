import UIKit

/// Ordnet einem Raumnamen ein Symbol zu — die Liste wird damit auf einen Blick
/// lesbar, ohne dass man Namen entziffern muss. Die Zuordnung ist bewusst
/// grosszügig: «Bad 2», «Badezimmer» und «Dusche» landen alle beim gleichen Zeichen.
func raumSymbol(_ name: String) -> String {
    let text = name.lowercased()

    let zuordnung: [(begriffe: [String], symbol: String)] = [
        (["küche", "kueche", "kochen"], "frying.pan"),
        (["bad", "dusche", "wc", "toilette", "sanitär", "sanitaer"], "shower"),
        (["wohn", "stube", "salon"], "sofa"),
        (["schlaf", "zimmer", "kind", "büro", "buero"], "bed.double"),
        (["keller", "treppe", "stiege"], "stairs"),
        (["flur", "gang", "korridor", "entree", "diele", "eingang"], "door.left.hand.open"),
        (["reduit", "abstell", "estrich", "vorrat", "lager"], "shippingbox"),
        (["wasch", "technik", "heizung"], "washer"),
        (["balkon", "terrasse", "sitzplatz", "loggia"], "sun.max"),
        (["garten", "umgebung", "aussen", "außen"], "tree"),
        (["garage", "einstell", "carport"], "car"),
        (["dach", "estrich"], "house"),
        (["fassade", "gerüst", "geruest", "rohbau"], "building.2")
    ]

    for eintrag in zuordnung where eintrag.begriffe.contains(where: text.contains) {
        return gepruef(eintrag.symbol)
    }
    return gepruef("door.left.hand.closed")
}

/// Sicherheitsnetz: kennt das System das Zeichen nicht, bleibt die Zeile trotzdem
/// vollständig statt leer.
private func gepruef(_ symbol: String) -> String {
    UIImage(systemName: symbol) != nil ? symbol : "square.grid.2x2"
}
