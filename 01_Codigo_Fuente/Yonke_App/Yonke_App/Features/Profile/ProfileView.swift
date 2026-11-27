import SwiftUI

// MARK: - ProfileView
/// Cuenta del usuario y datos de su yonque. Cerrar sesión regresa al login.

struct ProfileView: View {
    @ObservedObject private var authViewModel = AuthViewModel.shared
    @StateObject private var profileViewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                yonqueSection

                Section {
                    Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        authViewModel.logout()
                    }
                }
            }
            .yonkeGroupedBackground()
            .navigationTitle("Perfil")
            .task { await profileViewModel.load() }
            .refreshable { await profileViewModel.load() }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Cuenta") {
            if let user = authViewModel.currentUser {
                LabeledContent("Nombre", value: user.nombre)
                LabeledContent("Correo", value: user.email)
            }
        }
    }

    @ViewBuilder
    private var yonqueSection: some View {
        Section("Yonque") {
            if let yonque = profileViewModel.yonque {
                LabeledContent("Nombre", value: yonque.nombre)
                if let telefono = yonque.telefono, !telefono.isEmpty {
                    LabeledContent("Teléfono", value: telefono)
                }
                if let ubicacion = yonque.ubicacion, !ubicacion.linea.isEmpty {
                    LabeledContent("Dirección", value: ubicacion.linea)
                }
            } else if profileViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let error = profileViewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(YonkeTheme.accentRed)
                Button("Reintentar") {
                    Task { await profileViewModel.load() }
                }
            }
        }
    }
}
