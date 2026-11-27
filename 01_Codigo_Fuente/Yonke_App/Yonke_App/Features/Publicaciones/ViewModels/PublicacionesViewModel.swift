import Foundation
import Combine

// MARK: - PublicacionesViewModel
/// Pestaña Publicaciones: borradores abiertos y publicaciones filtradas por estado.

enum ModoPublicaciones: String, CaseIterable, Identifiable {
    case borradores = "Borradores"
    case publicadas = "Publicadas"
    case descartadas = "Descartadas"

    var id: String { rawValue }
}

@MainActor
final class PublicacionesViewModel: ObservableObject {

    @Published var modo: ModoPublicaciones = .borradores
    @Published var estadoFiltro: EstadoPublicacion?

    @Published private(set) var borradores: [Borrador] = []
    @Published private(set) var publicaciones: [Publicacion] = []
    @Published private(set) var borradoresDescartados: [Borrador] = []
    @Published private(set) var publicacionesEliminadas: [Publicacion] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: PublicacionServiceProtocol

    init(service: PublicacionServiceProtocol = RemotePublicacionService.shared) {
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let borradoresCargados = service.fetchBorradores()
            async let publicacionesCargadas = service.fetchPublicaciones(estado: estadoFiltro)
            async let descartadosCargados = service.fetchBorradoresDescartados()
            async let eliminadasCargadas = service.fetchPublicaciones(estado: .eliminada)
            borradores = try await borradoresCargados
            publicaciones = try await publicacionesCargadas
            borradoresDescartados = try await descartadosCargados
            publicacionesEliminadas = try await eliminadasCargadas
        } catch {
            #if DEBUG
            print("[API] Publicaciones.load falló: \(error)")
            #endif
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar las publicaciones."
        }
    }

    /// Vuelve a consultar solo las publicaciones (al cambiar el filtro).
    func recargarPublicadas() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            publicaciones = try await service.fetchPublicaciones(estado: estadoFiltro)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar las publicaciones."
        }
    }
}
