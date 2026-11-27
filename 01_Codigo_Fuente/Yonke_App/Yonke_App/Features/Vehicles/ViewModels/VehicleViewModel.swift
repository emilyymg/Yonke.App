import Foundation
import Combine

// MARK: - VehicleViewModel
/// Pestaña Vehículos: vehículos del yonque del usuario (GET /api/vehiculos).

@MainActor
final class VehicleViewModel: ObservableObject {

    @Published private(set) var vehiculos: [VehiculoInventario] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: InventoryServiceProtocol

    init(service: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            vehiculos = try await service.fetchVehiculos()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar los vehículos."
        }
    }
}
