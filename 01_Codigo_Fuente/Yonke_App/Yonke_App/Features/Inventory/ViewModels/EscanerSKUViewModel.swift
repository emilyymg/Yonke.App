import Foundation
import Combine

// MARK: - EscanerSKUViewModel
/// Busca la pieza por el código leído. Un mismo código no se consulta de nuevo
/// hasta que el usuario reinicia el escáner; la cámara repite la lectura en cada cuadro.

@MainActor
final class EscanerSKUViewModel: ObservableObject {

    @Published private(set) var buscando = false
    @Published private(set) var errorMessage: String?
    @Published var codigoManual = ""

    private var ultimoCodigo: String?
    private let service: InventoryServiceProtocol

    init(service: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.service = service
    }

    /// Devuelve la pieza encontrada, o nil si no hay coincidencia o ya se intentó ese código.
    func buscar(_ codigo: String) async -> PiezaInventario? {
        let limpio = codigo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty, !buscando, limpio != ultimoCodigo else { return nil }

        ultimoCodigo = limpio
        buscando = true
        errorMessage = nil
        defer { buscando = false }

        do {
            return try await service.fetchPiezaPorSku(limpio)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo buscar la pieza."
            return nil
        }
    }

    /// Permite volver a leer el mismo código, por ejemplo después de un error.
    func reiniciar() {
        ultimoCodigo = nil
        errorMessage = nil
    }
}
