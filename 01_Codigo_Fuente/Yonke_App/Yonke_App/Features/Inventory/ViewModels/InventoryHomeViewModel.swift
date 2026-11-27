import Foundation
import Combine

// MARK: - InventoryHomeViewModel
/// Estado de la pestaña Inventario: vehículos con sus piezas, filtro por
/// estado (consulta al servicio) y búsqueda por nombre o SKU (local).

struct VehiculoConPiezas: Identifiable {
    let vehiculo: VehiculoInventario
    let piezas: [PiezaInventario]
    var id: String { vehiculo.id }
}

@MainActor
final class InventoryHomeViewModel: ObservableObject {

    @Published private(set) var vehiculos: [VehiculoInventario] = []
    @Published private(set) var piezas: [PiezaInventario] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published var estadoFiltro: EstadoPieza?
    @Published var searchText = ""
    /// Error de una acción (p. ej. eliminar vehículo), se muestra en una alerta.
    @Published var accionError: String?

    private let service: InventoryServiceProtocol

    init(service: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.service = service
    }

    /// Piezas agrupadas por vehículo, con el filtro de búsqueda aplicado.
    /// Los vehículos sin piezas coincidentes se omiten.
    var grupos: [VehiculoConPiezas] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtradas = query.isEmpty ? piezas : piezas.filter {
            $0.nombre.localizedStandardContains(query) ||
            ($0.sku?.localizedStandardContains(query) ?? false)
        }

        return vehiculos.compactMap { vehiculo in
            let propias = filtradas.filter { $0.vehiculoId == vehiculo.id }
            return propias.isEmpty ? nil : VehiculoConPiezas(vehiculo: vehiculo, piezas: propias)
        }
    }

    func vehiculo(id: String) -> VehiculoInventario? {
        vehiculos.first { $0.id == id }
    }

    /// Aplica un cambio hecho en el detalle sin volver a consultar.
    /// Si la pieza ya no cumple el filtro de estado, sale de la lista.
    func actualizar(_ pieza: PiezaInventario) {
        if let estado = estadoFiltro, pieza.estado != estado {
            piezas.removeAll { $0.id == pieza.id }
        } else if let indice = piezas.firstIndex(where: { $0.id == pieza.id }) {
            piezas[indice] = pieza
        }
    }

    /// Elimina el vehículo en el backend y lo quita de la lista. Devuelve true si se eliminó.
    func eliminarVehiculo(id: String) async -> Bool {
        accionError = nil
        do {
            try await service.eliminarVehiculo(id: id)
            vehiculos.removeAll { $0.id == id }
            piezas.removeAll { $0.vehiculoId == id }
            return true
        } catch {
            accionError = (error as? LocalizedError)?.errorDescription ?? "No se pudo eliminar el vehículo."
            return false
        }
    }

    /// Tras registrar un vehículo, muestra la cola de piezas por confirmar.
    func didRegistrar() async {
        estadoFiltro = .porConfirmar
        await load()
    }

    /// Inserta la pieza manual recién creada para mostrarla de inmediato y recarga en segundo plano.
    func didCrearPiezaManual(_ pieza: PiezaInventario) {
        if let filtro = estadoFiltro, filtro != pieza.estado {
            estadoFiltro = nil
        }
        if !piezas.contains(where: { $0.id == pieza.id }) {
            piezas.insert(pieza, at: 0)
        }
        Task { await load() }
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let vehiculosCargados = service.fetchVehiculos()
            async let piezasCargadas = service.fetchPiezas(estado: estadoFiltro)
            vehiculos = try await vehiculosCargados
            piezas = try await piezasCargadas
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Vuelve a consultar solo las piezas (al cambiar el filtro de estado).
    func reloadPiezas() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            piezas = try await service.fetchPiezas(estado: estadoFiltro)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar el inventario."
    }
}
