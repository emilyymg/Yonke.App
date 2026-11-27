import Foundation
import Combine

// MARK: - VenderPiezaViewModel
/// Captura los datos de la venta y la registra con `procesar_venta`.

@MainActor
final class VenderPiezaViewModel: ObservableObject {

    let pieza: PiezaInventario

    @Published var compradorNombre = ""
    @Published var precioTexto: String
    @Published var metodoPago: MetodoPago = .efectivo
    @Published var notas = ""
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let service: VentaServiceProtocol

    init(pieza: PiezaInventario, service: VentaServiceProtocol = RemoteVentaService.shared) {
        self.pieza = pieza
        self.service = service
        self.precioTexto = pieza.precioVenta.map { String($0) } ?? ""
    }

    /// Precio final en pesos. Acepta coma o punto como separador decimal.
    var precio: Double? {
        let limpio = precioTexto
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let valor = Double(limpio), valor > 0 else { return nil }
        return valor
    }

    var puedeRegistrar: Bool {
        precio != nil && !isSaving
    }

    /// Devuelve la venta registrada, o nil si falló.
    func registrar() async -> Venta? {
        guard let precio, !isSaving else {
            errorMessage = "Captura un precio final mayor a cero."
            return nil
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            return try await service.venderPieza(
                piezaId: pieza.id,
                input: VentaInput(compradorNombre: compradorNombre,
                                  precioFinal: precio,
                                  metodoPago: metodoPago,
                                  notas: notas)
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo registrar la venta."
            return nil
        }
    }
}
