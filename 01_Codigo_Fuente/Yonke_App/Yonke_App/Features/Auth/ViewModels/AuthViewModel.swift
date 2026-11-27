import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()

    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: AuthUser?

    private let api: APIClient
    private let keychain: KeychainManager

    init(api: APIClient = .shared, keychain: KeychainManager = .shared) {
        self.api = api
        self.keychain = keychain

        // Restaura la sesión guardada en Keychain.
        if keychain.readToken() != nil, let user = keychain.readUser() {
            currentUser = user
            isAuthenticated = true
        }

        // Cualquier 401 en una petición autenticada cierra la sesión.
        api.onUnauthorized = { [weak self] in
            Task { @MainActor in
                self?.handleSessionExpired()
            }
        }
    }

    func login() async {
        guard !isLoading else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Por favor ingresa tu correo y contraseña."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: LoginResponse = try await api.request(
                .post,
                APIPath.login,
                body: LoginRequest(email: trimmedEmail, contrasena: password)
            )

            guard keychain.saveToken(response.token), keychain.saveUser(response.user) else {
                keychain.clearSession()
                errorMessage = "No se pudo guardar la sesión de forma segura."
                return
            }

            currentUser = response.user
            password = ""
            isAuthenticated = true
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Cierra la sesión local. `message` se muestra en la pantalla de login.
    func logout(message: String? = nil) {
        keychain.clearSession()
        currentUser = nil
        isAuthenticated = false
        password = ""
        errorMessage = message
    }

    // MARK: - Private

    private func handleSessionExpired() {
        guard isAuthenticated else { return }
        logout(message: APIError.unauthorized.errorDescription)
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? APIError, let description = apiError.errorDescription {
            return description
        }
        return "Ocurrió un error inesperado."
    }
}
