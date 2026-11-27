import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var yonque: Yonque?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            yonque = try await api.request(.get, APIPath.yonqueMio)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription
                ?? "No se pudieron cargar los datos del yonque."
        }
    }
}
