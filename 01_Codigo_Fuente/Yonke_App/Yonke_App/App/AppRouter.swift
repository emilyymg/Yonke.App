import SwiftUI

// MARK: - AppRouter
/// Root router: shows the login screen until the user is authenticated,
/// then the main tab bar. The dark palette is applied app-wide.

struct AppRouter: View {
    @StateObject private var authViewModel = AuthViewModel.shared
    @State private var selectedTab: AppTab = .home
    @State private var filtroInventarioSolicitado: EstadoPieza?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                mainTabView
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, fase in
            // Reintenta las subidas pendientes al volver a primer plano.
            if fase == .active {
                Task { await FotoUploadQueue.shared.procesar() }
            }
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Inicio", systemImage: "house.fill", value: AppTab.home) {
                InicioView(
                    onIrAInventario: { filtro in
                        filtroInventarioSolicitado = filtro
                        selectedTab = .inventory
                    },
                    onIrAPublicaciones: { selectedTab = .publications },
                    onIrAVentas: { selectedTab = .sales }
                )
            }

            Tab("Inventario", systemImage: "shippingbox.fill", value: AppTab.inventory) {
                InventoryHomeView(filtroSolicitado: $filtroInventarioSolicitado)
            }

            Tab("Publicaciones", systemImage: "doc.text.fill", value: AppTab.publications) {
                PublicacionesView()
            }

            Tab("Ventas", systemImage: "banknote.fill", value: AppTab.sales) {
                VentasView()
            }

            Tab("Perfil", systemImage: "person.fill", value: AppTab.profile) {
                ProfileView()
            }
        }
        .tint(YonkeTheme.accentRed)
    }
}
