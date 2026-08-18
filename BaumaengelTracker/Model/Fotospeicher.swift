import UIKit

/// Fotos liegen als JPEG unter Documents/Fotos. In der Datenbank steht nur der
/// Dateiname — das hält den Store klein und macht den PDF-Export einfach.
enum Fotospeicher {

    static let maximaleKante: CGFloat = 2000
    static let qualitaet: CGFloat = 0.8

    private static let vorschauCache = NSCache<NSString, UIImage>()

    static var ordner: URL {
        let basis = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ziel = basis.appendingPathComponent("Fotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: ziel.path) {
            try? FileManager.default.createDirectory(at: ziel, withIntermediateDirectories: true)
        }
        return ziel
    }

    static func url(_ name: String) -> URL {
        ordner.appendingPathComponent(name)
    }

    /// Speichert ein Bild verkleinert als JPEG und gibt den Dateinamen zurück.
    @discardableResult
    static func speichern(_ bild: UIImage) -> String? {
        let verkleinert = verkleinern(bild, maximaleKante: maximaleKante)
        guard let daten = verkleinert.jpegData(compressionQuality: qualitaet) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try daten.write(to: url(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func bild(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: url(name).path)
    }

    /// Kleine Fassung fürs Blättern in Listen — einmal gerechnet, dann gecacht.
    static func vorschau(_ name: String, kante: CGFloat = 240) -> UIImage? {
        let schluessel = "\(name)@\(Int(kante))" as NSString
        if let treffer = vorschauCache.object(forKey: schluessel) { return treffer }
        guard let voll = bild(name) else { return nil }
        let klein = verkleinern(voll, maximaleKante: kante)
        vorschauCache.setObject(klein, forKey: schluessel)
        return klein
    }

    /// Für den PDF-Export: verkleinert **und** als JPEG codiert. Ein aus einem
    /// Bitmap gezeichnetes Bild landet sonst praktisch unkomprimiert im
    /// Dokument — bei 90 Fotos ist das der Unterschied zwischen 15 MB und 4 MB.
    static func fuerDruck(_ name: String, kante: CGFloat = 520,
                          qualitaet: CGFloat = 0.6) -> UIImage? {
        guard let voll = bild(name) else { return nil }
        let klein = verkleinern(voll, maximaleKante: kante)
        guard let daten = klein.jpegData(compressionQuality: qualitaet) else { return klein }
        return UIImage(data: daten)
    }

    /// Für die Sicherung: auf 1600 px verkleinert und als JPEG codiert. Der
    /// Beleg bleibt aussagekräftig, die Datei versendbar.
    static func fuerSicherung(_ name: String) -> Data? {
        guard let voll = bild(name) else { return nil }
        return verkleinern(voll, maximaleKante: 1600).jpegData(compressionQuality: 0.75)
    }

    /// Legt Bilddaten aus einer Sicherung unter einem neuen Namen ab.
    static func ablegen(_ daten: Data) -> String? {
        let name = UUID().uuidString + ".jpg"
        do {
            try daten.write(to: url(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func loeschen(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
        vorschauCache.removeAllObjects()
    }

    static func loeschen(_ namen: [String]) {
        namen.forEach(loeschen)
    }

    /// Entfernt Dateien, auf die kein Mangel mehr zeigt — etwa wenn die App
    /// beendet wurde, während ein Mangel noch unbestätigt in Arbeit war.
    static func aufraeumen(bekannt: Set<String>) {
        guard let dateien = try? FileManager.default.contentsOfDirectory(
            at: ordner, includingPropertiesForKeys: nil) else { return }
        for datei in dateien where !bekannt.contains(datei.lastPathComponent) {
            try? FileManager.default.removeItem(at: datei)
        }
    }

    private static func verkleinern(_ bild: UIImage, maximaleKante: CGFloat) -> UIImage {
        let groesste = max(bild.size.width, bild.size.height)
        guard groesste > maximaleKante else { return bild }
        let faktor = maximaleKante / groesste
        let ziel = CGSize(width: bild.size.width * faktor, height: bild.size.height * faktor)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: ziel, format: format).image { _ in
            bild.draw(in: CGRect(origin: .zero, size: ziel))
        }
    }
}
