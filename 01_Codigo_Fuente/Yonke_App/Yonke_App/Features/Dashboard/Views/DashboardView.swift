import SwiftUI

// MARK: - DashboardView
/// TabView hub with the dark theme and red accent tint.
/// Simply delegates to AppRouter's tabs.

struct DashboardView: View {
    var body: some View {
        TabView {
            VehicleListView()
                .tabItem {
                    Label("Vehículos", systemImage: "car.fill")
                }

            InventoryBoardView()
                .tabItem {
                    Label("Inventario", systemImage: "shippingbox.fill")
                }

            CameraView()
                .tabItem {
                    Label("Escáner", systemImage: "camera.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
        }
        .tint(YonkeTheme.accentRed)
        .preferredColorScheme(.dark)
    }
}
