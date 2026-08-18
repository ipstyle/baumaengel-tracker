import SwiftUI

/// Namen der Einstellungen an einem Ort — sonst driften die Zeichenketten
/// zwischen den Ansichten auseinander.
enum Schluessel {
    static let erscheinungsbild = "erscheinungsbild"
    static let kompakt = "kompakt"
    static let statusfilter = "statusfilter"
}

enum Erscheinungsbild: String, CaseIterable, Identifiable {
    case system, hell, dunkel

    var id: String { rawValue }

    var beschriftung: String {
        switch self {
        case .system: return "System"
        case .hell: return "Hell"
        case .dunkel: return "Dunkel"
        }
    }

    /// `nil` überlässt die Entscheidung dem Gerät.
    var farbschema: ColorScheme? {
        switch self {
        case .system: return nil
        case .hell: return .light
        case .dunkel: return .dark
        }
    }
}
