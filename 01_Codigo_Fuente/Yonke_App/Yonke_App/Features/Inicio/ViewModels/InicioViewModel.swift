import Foundation
import Combine

// MARK: - InicioViewModel
/// Estado de la pestaña Inicio: resumen del yonque, alertas de inventario y ventas recientes.

@MainActor
final class InicioViewModel: ObservableObject {

    static let umbralInventarioBajo = 5

    @Published private(set) var yonque: Yonque?
    @Published private(set) var ventasRecientes: [Venta] = []
    @Published private(set) var vehiculos: [VehiculoInventario] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api: APIClient
    private let ventaService: VentaServiceProtocol
    private let inventoryService: InventoryServiceProtocol

    init(api: APIClient = .shared,
         ventaService: VentaServiceProtocol = RemoteVentaService.shared,
         inventoryService: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.api = api
        self.ventaService = ventaService
        self.inventoryService = inventoryService
    }

    var resumen: Yonque.Resumen? { yonque?.resumen }

    var piezasPorConfirmar: Int { resumen?.piezasPorConfirmar ?? 0 }

    var piezasDisponibles: Int { resumen?.piezasDisponibles ?? 0 }

    var publicacionesActivas: Int { resumen?.publicacionesActivas ?? 0 }

    var totalVehiculos: Int { resumen?.totalVehiculos ?? 0 }

    var alertaInventarioBajo: Bool {
        guard let resumen else { return false }
        return resumen.piezasDisponibles < Self.umbralInventarioBajo
    }

    var alertaSinPublicar: Bool {
        guard let resumen else { return false }
        return resumen.publicacionesActivas == 0 && resumen.piezasDisponibles > 0
    }

    var tieneAlertas: Bool {
        piezasPorConfirmar > 0 || alertaInventarioBajo || alertaSinPublicar
    }

    func vehiculo(id: String) -> VehiculoInventario? {
        vehiculos.first { $0.id == id }
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let ventasCargadas = ventaService.fetchVentas()
            async let vehiculosCargados = inventoryService.fetchVehiculos()

            yonque = try await api.request(.get, APIPath.yonqueMio)
            ventasRecientes = Array(((try? await ventasCargadas) ?? []).prefix(5))
            vehiculos = (try? await vehiculosCargados) ?? []
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "No se pudo cargar el resumen del yonque."
        }
    }
}

