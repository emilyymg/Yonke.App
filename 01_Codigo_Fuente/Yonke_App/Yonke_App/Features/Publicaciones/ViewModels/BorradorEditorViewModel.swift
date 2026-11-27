import Foundation
import Combine

// MARK: - BorradorEditorViewModel
/// Edición de un borrador antes de publicarlo: título, descripción, precio,
/// condición y qué fotos de la pieza se publican.

@MainActor
final class BorradorEditorViewModel: ObservableObject {

    @Published private(set) var borrador: Borrador
    @Published var titulo: String
    @Published var descripcion: String
    @Published var precioTexto: String
    @Published var condicion: CondicionPieza?
    /// Ids de `fotos` seleccionadas, en el orden en que se marcaron.
    @Published private(set) var fotosSeleccionadas: [String]

    @Published private(set) var fotosPieza: [FotoPieza] = []
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    /// Se asigna al publicarse con éxito. La vista cierra la hoja al recibirlo.
    @Published private(set) var publicacion: Publicacion?

    private let publicaciones: PublicacionServiceProtocol
    private let inventario: InventoryServiceProtocol

    init(borrador: Borrador,
         publicaciones: PublicacionServiceProtocol = RemotePublicacionService.shared,
         inventario: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.borrador = borrador
        self.publicaciones = publicaciones
        self.inventario = inventario
        self.titulo = borrador.titulo ?? ""
        self.descripcion = borrador.descripcionMarketplace ?? ""
        self.precioTexto = borrador.precioPublico.map { String($0) } ?? ""
        self.condicion = borrador.condicionPublicada
        self.fotosSeleccionadas = borrador.fotosMarketplace
    }

    /// Precio en pesos. Acepta coma o punto como separador decimal.
    var precio: Double? {
        let limpio = precioTexto
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let valor = Double(limpio), valor > 0 else { return nil }
        return valor
    }

    var tituloValido: Bool {
        !titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var puedePublicar: Bool {
        tituloValido && precio != nil && borrador.estado.estaAbierto && !isWorking
    }

    var puedeGuardar: Bool {
        borrador.estado.estaAbierto && !isWorking
    }

    func cargarFotos() async {
        do {
            let pieza = try await inventario.fetchPieza(id: borrador.piezaId)
            fotosPieza = pieza.fotos.sorted { $0.orden < $1.orden }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar las fotos."
        }
    }

    func alternarFoto(_ id: String) {
        if let indice = fotosSeleccionadas.firstIndex(of: id) {
            fotosSeleccionadas.remove(at: indice)
        } else {
            fotosSeleccionadas.append(id)
        }
    }

    func estaSeleccionada(_ id: String) -> Bool {
        fotosSeleccionadas.contains(id)
    }

    /// Guarda sin marcar listo. Devuelve true si se guardó.
    func guardar() async -> Bool {
        await ejecutar { try await self.actualizar(marcarListo: false) } != nil
    }

    /// Marca el borrador como listo y lo publica.
    func publicar() async {
        guard puedePublicar else { return }
        let resultado = await ejecutar {
            let listo = try await self.actualizar(marcarListo: true)
            return try await self.publicaciones.publicar(borradorId: listo.id)
        }
        if let resultado {
            publicacion = resultado
        }
    }

    /// Descarta el borrador (estado `descartado`, sin borrado físico).
    func descartar() async -> Bool {
        await ejecutar {
            try await self.publicaciones.descartarBorrador(id: self.borrador.id)
        } != nil
    }

    // MARK: - Helpers

    private func actualizar(marcarListo: Bool) async throws -> Borrador {
        let cambios = BorradorCambios(
            titulo: titulo,
            descripcion: descripcion,
            precio: precio,
            condicion: condicion,
            fotosMarketplace: fotosSeleccionadas,
            marcarListo: marcarListo
        )
        let actualizado = try await publicaciones.actualizarBorrador(id: borrador.id, cambios: cambios)
        borrador = actualizado
        return actualizado
    }

    /// Envuelve una operación con el indicador de trabajo y el mensaje de error.
    private func ejecutar<T>(_ operacion: () async throws -> T) async -> T? {
        guard !isWorking else { return nil }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            return try await operacion()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo completar la acción."
            return nil
        }
    }
}
