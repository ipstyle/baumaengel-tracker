import SwiftUI
import UIKit

/// Dünne Hülle um den System-Bildaufnehmer. Wird nur geöffnet, wenn es eine
/// Kamera gibt und die Freigabe erteilt ist — sonst bleibt der Knopf verborgen.
struct KameraAufnahme: UIViewControllerRepresentable {

    let fertig: (UIImage) -> Void
    @Environment(\.dismiss) private var schliessen

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Kann im Simulator vorkommen: leerer Bildschirm statt Absturz.
            return UIViewController()
        }
        let aufnehmer = UIImagePickerController()
        aufnehmer.sourceType = .camera
        aufnehmer.allowsEditing = false
        aufnehmer.delegate = context.coordinator
        return aufnehmer
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(fertig: fertig, schliessen: { schliessen() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let fertig: (UIImage) -> Void
        private let schliessen: () -> Void

        init(fertig: @escaping (UIImage) -> Void, schliessen: @escaping () -> Void) {
            self.fertig = fertig
            self.schliessen = schliessen
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let bild = info[.originalImage] as? UIImage {
                fertig(bild)
            }
            schliessen()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            schliessen()
        }
    }
}
