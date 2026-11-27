import SwiftUI
import UIKit

// MARK: - CamaraPicker
/// Cámara del sistema para fotografiar una pieza. Requiere NSCameraUsageDescription.

struct CamaraPicker: UIViewControllerRepresentable {
    let onCapturar: (UIImage) -> Void
    let onCancelar: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapturar: onCapturar, onCancelar: onCancelar)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapturar: (UIImage) -> Void
        private let onCancelar: () -> Void

        init(onCapturar: @escaping (UIImage) -> Void, onCancelar: @escaping () -> Void) {
            self.onCapturar = onCapturar
            self.onCancelar = onCancelar
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let imagen = info[.originalImage] as? UIImage {
                onCapturar(imagen)
            } else {
                onCancelar()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancelar()
        }
    }
}
