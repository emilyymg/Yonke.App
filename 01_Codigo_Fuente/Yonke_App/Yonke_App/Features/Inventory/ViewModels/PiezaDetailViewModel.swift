import Foundation
import Combine

// MARK: - PiezaDetailViewModel
/// Estado del detalle de una pieza. Ejecuta los cambios de estado directos
/// (reservar, liberar, descartar) e inicia la publicación. Confirmar tiene su
/// propia hoja porque pide precio y condición; el editor de borrador también tiene la suya.

@MainActor
final class PiezaDetailViewModel: ObservableObject {

    @Published private(set) var pieza: PiezaInventario
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    /// Borrador abierto en el editor. Al asignarlo, la vista presenta la hoja.
    @Published var borradorEnEdicion: Borrador?
    /// Venta vigente de la pieza vendida. Al asignarla, la vista presenta su detalle.
    @Published var ventaEnDetalle: Venta?

    private let service: InventoryServiceProtocol
    private let publicaciones: PublicacionServiceProtocol
    private let ventas: VentaServiceProtocol
    private let onCambio: (PiezaInventario) -> Void

    init(pieza: PiezaInventario,
         service: InventoryServiceProtocol = RemoteInventoryService.shared,
         publicaciones: PublicacionServiceProtocol = RemotePublicacionService.shared,
         ventas: VentaServiceProtocol = RemoteVentaService.shared,
         onCambio: @escaping (PiezaInventario) -> Void = { _ in }) {
        self.pieza = pieza
        self.service = service
        self.publicaciones = publicaciones
        self.ventas = ventas
        self.onCambio = onCambio
    }

    /// Busca la venta vigente de la pieza para mostrar su detalle.
    func abrirVenta() async {
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            guard let venta = try await ventas.fetchVentaDePieza(piezaId: pieza.id) else {
                errorMessage = "No hay una venta vigente para esta pieza."
                return
            }
            ventaEnDetalle = venta
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar la venta."
        }
    }

    /// Devuelve la venta vigente de la pieza. La pieza vuelve a disponible.
    func devolverVenta() async {
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            guard let venta = try await ventas.fetchVentaDePieza(piezaId: pieza.id) else {
                errorMessage = "No hay una venta vigente para esta pieza."
                return
            }
            _ = try await ventas.devolverVenta(id: venta.id)
            aplicar(try await service.fetchPieza(id: pieza.id))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo devolver la venta."
        }
    }

    /// Ejecuta una acción de cambio de estado directo.
    func ejecutar(_ accion: AccionPieza) async {
        guard !isWorking, let destino = accion.destino else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let actualizada = try await service.cambiarEstado(
                piezaId: pieza.id,
                nuevo: destino,
                motivo: accion.titulo
            )
            aplicar(actualizada)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo completar la acción."
        }
    }

    /// Abre el borrador abierto de la pieza, o crea uno nuevo con título y descripción sugeridos.
    func iniciarPublicacion() async {
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let abiertos = try await publicaciones.fetchBorradores()
            if let existente = abiertos.first(where: { $0.piezaId == pieza.id }) {
                borradorEnEdicion = existente
            } else {
                borradorEnEdicion = try await publicaciones.crearBorrador(piezaId: pieza.id)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo iniciar la publicación."
        }
    }

    /// Vuelve a leer la pieza para ver fotos nuevas (derivados listos).
    func refrescar() async {
        do {
            aplicar(try await service.fetchPieza(id: pieza.id))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo actualizar la pieza."
        }
    }

    /// Recibe la pieza ya actualizada desde la hoja de confirmación.
    func aplicar(_ actualizada: PiezaInventario) {
        pieza = actualizada
        onCambio(actualizada)
    }
}
