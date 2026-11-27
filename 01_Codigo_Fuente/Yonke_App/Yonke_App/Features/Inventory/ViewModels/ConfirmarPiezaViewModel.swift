import Foundation
import Combine

// MARK: - ConfirmarPiezaViewModel
/// Captura precio y condición de una pieza por confirmar y la deja disponible.

@MainActor
final class ConfirmarPiezaViewModel: ObservableObject {

    let pieza: PiezaInventario

    @Published var precioTexto = ""
    @Published var condicion: CondicionPieza?
    @Published private(set) var fotos: [FotoPieza]
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let service: InventoryServiceProtocol

    init(pieza: PiezaInventario, service: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.pieza = pieza
        self.service = service
        self.fotos = pieza.fotos
        self.condicion = pieza.condicion
        if let precio = pieza.precioVenta {
            self.precioTexto = String(precio)
        }
    }

    /// Precio en pesos. Acepta coma o punto como separador decimal.
    var precio: Double? {
        let limpio = precioTexto
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let valor = Double(limpio), valor > 0 else { return nil }
        return valor
    }

    var puedeGuardar: Bool {
        precio != nil && condicion != nil && !isSaving
    }

    /// Vuelve a leer la pieza para reflejar fotos recién subidas o borradas.
    func refrescarFotos() async {
        do {
            fotos = try await service.fetchPieza(id: pieza.id).fotos
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron actualizar las fotos."
        }
    }

    /// Devuelve la pieza confirmada, o nil si falló.
    func confirmar() async -> PiezaInventario? {
        guard let precio, let condicion, !isSaving else {
            errorMessage = "Captura un precio mayor a cero y la condición."
            return nil
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            return try await service.confirmarPieza(id: pieza.id, precioVenta: precio, condicion: condicion)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo confirmar la pieza."
            return nil
        }
    }
}
