import SwiftUI

// MARK: - CameraView
/// Placeholder for the upcoming VIN and part scanner.

struct CameraView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Escáner",
                systemImage: "camera.viewfinder",
                description: Text("Próximamente: escaneo de VIN y piezas con la cámara.")
            )
            .navigationTitle("Escáner")
        }
    }
}
