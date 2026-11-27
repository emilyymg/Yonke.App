import Foundation
import Combine

// MARK: - RegistrarVehiculoViewModel
/// Alta de vehículo desde el catálogo de marcas y modelos. La base genera las piezas por confirmar.

@MainActor
final class RegistrarVehiculoViewModel: ObservableObject {

    /// Año más antiguo permitido en el selector.
    static let anioMinimo = 1960

    @Published private(set) var marcas: [MarcaVehiculo] = []
    @Published private(set) var modelos: [ModeloVehiculo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    @Published var marcaId: String?
    @Published var modeloId: String?
    @Published var anio: Int = Calendar.current.component(.year, from: Date())

    private let service: InventoryServiceProtocol

    init(service: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.service = service
    }

    /// Años disponibles, del más reciente al más antiguo.
    var aniosDisponibles: [Int] {
        let actual = Calendar.current.component(.year, from: Date())
        return Array((Self.anioMinimo...(actual + 1)).reversed())
    }

    var puedeRegistrar: Bool {
        modeloId != nil && aniosDisponibles.contains(anio) && !isSaving
    }

    func cargarMarcas() async {
        guard marcas.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            marcas = try await service.fetchMarcas()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar el catálogo."
        }
    }

    /// Al cambiar de marca, limpia el modelo y carga los de la nueva marca.
    func marcaSeleccionada() async {
        modeloId = nil
        modelos = []
        guard let marcaId else { return }

        do {
            modelos = try await service.fetchModelos(marcaId: marcaId)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar los modelos."
        }
    }

    /// Devuelve el resultado del registro, o nil si falló.
    func registrar() async -> RegistroVehiculoResultado? {
        guard let modeloId, puedeRegistrar else {
            errorMessage = "Selecciona marca, modelo y año."
            return nil
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            return try await service.registrarVehiculo(modeloId: modeloId, anio: anio)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo registrar el vehículo."
            return nil
        }
    }
}
