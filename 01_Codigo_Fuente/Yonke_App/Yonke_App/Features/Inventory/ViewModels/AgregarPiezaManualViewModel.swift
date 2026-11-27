import Foundation
import Combine

// MARK: - AgregarPiezaManualViewModel
/// Crea una pieza suelta fuera de plantilla asociada a un vehículo del yonque.

@MainActor
final class AgregarPiezaManualViewModel: ObservableObject {

    @Published private(set) var vehiculos: [VehiculoInventario]
    @Published var vehiculoId: String?
    @Published var nombre = ""
    @Published var descripcion = ""
    @Published var condicion: CondicionPieza?
    @Published var precioTexto = ""

    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let service: InventoryServiceProtocol

    init(vehiculosIniciales: [VehiculoInventario] = [],
         service: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.vehiculos = vehiculosIniciales
        self.vehiculoId = vehiculosIniciales.first?.id
        self.service = service
    }

    private var precioLimpio: String {
        precioTexto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    }

    var precio: Double? {
        guard !precioLimpio.isEmpty, let valor = Double(precioLimpio), valor > 0 else { return nil }
        return valor
    }

    var precioInvalido: Bool {
        !precioLimpio.isEmpty && !(Double(precioLimpio).map { $0 > 0 } ?? false)
    }

    var puedeGuardar: Bool {
        vehiculoId != nil
            && !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !precioInvalido
            && !isSaving
    }

    func cargarVehiculosSiFaltan() async {
        guard vehiculos.isEmpty, !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            vehiculos = try await service.fetchVehiculos()
            if vehiculoId == nil {
                vehiculoId = vehiculos.first?.id
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar los vehículos."
        }
    }

    func guardar() async -> PiezaInventario? {
        guard let vehiculoId else {
            errorMessage = "Selecciona un vehículo."
            return nil
        }
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombreLimpio.isEmpty else {
            errorMessage = "Escribe el nombre de la pieza."
            return nil
        }
        guard !precioInvalido else {
            errorMessage = "El precio debe ser mayor a cero."
            return nil
        }
        guard !isSaving else { return nil }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let descripcionLimpia = descripcion.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            return try await service.crearPiezaManual(
                vehiculoId: vehiculoId,
                nombre: nombreLimpio,
                descripcion: descripcionLimpia.isEmpty ? nil : descripcionLimpia,
                condicion: condicion,
                precioVenta: precio
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo agregar la pieza."
            return nil
        }
    }
}

