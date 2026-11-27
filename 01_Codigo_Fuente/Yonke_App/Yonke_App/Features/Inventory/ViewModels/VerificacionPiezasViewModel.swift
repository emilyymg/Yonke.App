import Foundation
import Combine

// MARK: - DatosPiezaTarjeta
/// Campos editables de la tarjeta de una pieza. Se guardan con PATCH al aceptar.

struct DatosPiezaTarjeta: Equatable {
    var descripcion = ""
    var condicion: CondicionPieza?
    var precioTexto = ""

    init() {}

    init(pieza: PiezaInventario) {
        descripcion = pieza.descripcion ?? ""
        condicion = pieza.condicion
        precioTexto = pieza.precioVenta.map { String($0) } ?? ""
    }

    private var limpio: String {
        precioTexto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    }

    /// Precio en pesos. Vacío significa "sin precio" (la pieza queda por confirmar).
    var precio: Double? {
        guard !limpio.isEmpty, let valor = Double(limpio), valor > 0 else { return nil }
        return valor
    }

    /// Texto escrito que no es un precio válido.
    var precioInvalido: Bool {
        !limpio.isEmpty && !(Double(limpio).map { $0 > 0 } ?? false)
    }
}

// MARK: - VerificacionPiezasViewModel
/// Recorre las piezas por confirmar de un vehículo, una tarjeta a la vez.
/// Deslizar a la izquierda descarta (la pieza no existe en el vehículo);
/// deslizar a la derecha la acepta. Al final, el resumen confirma en lote.

@MainActor
final class VerificacionPiezasViewModel: ObservableObject {

    let vehiculoId: String

    @Published private(set) var tituloVehiculo: String?
    /// Tarjetas pendientes. La primera es la que se muestra.
    @Published private(set) var porRevisar: [PiezaInventario] = []
    @Published private(set) var aceptadas: [PiezaInventario] = []
    @Published private(set) var descartadas = 0

    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    /// true cuando ya no quedan tarjetas: se muestra el resumen.
    @Published var enResumen = false
    @Published var errorMessage: String?
    /// Resultado de la confirmación. Al cerrarlo, la hoja termina.
    @Published var resultadoConfirmacion: ResultadoVerificacion?

    private let service: InventoryServiceProtocol

    init(vehiculoId: String, service: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.vehiculoId = vehiculoId
        self.service = service
    }

    var actual: PiezaInventario? { porRevisar.first }

    var totalPiezas: Int { porRevisar.count + aceptadas.count + descartadas }

    var revisadas: Int { aceptadas.count + descartadas }

    var puedeConfirmar: Bool { !aceptadas.isEmpty && !isWorking }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let piezasCargadas = service.fetchPiezasDeVehiculo(vehiculoId: vehiculoId)
            async let vehiculosCargados = service.fetchVehiculos()

            let todas = try await piezasCargadas
            porRevisar = todas.filter { $0.estado == .porConfirmar }
            tituloVehiculo = (try? await vehiculosCargados)?.first { $0.id == vehiculoId }?.titulo
            enResumen = porRevisar.isEmpty
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar las piezas."
        }
    }

    /// Guarda los datos de la tarjeta y la acepta. Si falla, la tarjeta sigue pendiente.
    func aceptar(datos: DatosPiezaTarjeta) async {
        guard let pieza = actual, !isWorking else { return }
        guard !datos.precioInvalido else {
            errorMessage = "El precio debe ser mayor a cero."
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let guardada = try await service.actualizarPieza(
                id: pieza.id, nombre: nil,
                descripcion: datos.descripcion,
                condicion: datos.condicion,
                precioVenta: datos.precio
            )
            aceptadas.append(guardada)
            porRevisar.removeAll { $0.id == pieza.id }
            enResumen = porRevisar.isEmpty
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo guardar la pieza."
        }
    }

    /// La pieza no existe en este vehículo. Se borra o se marca descartada según su historial.
    func descartar() async {
        guard let pieza = actual, !isWorking else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await service.descartarPieza(id: pieza.id)
            porRevisar.removeAll { $0.id == pieza.id }
            descartadas += 1
            enResumen = porRevisar.isEmpty
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo descartar la pieza."
        }
    }

    /// Crea una pieza fuera de catálogo. Se agrega como nueva tarjeta y regresa al recorrido.
    @discardableResult
    func agregarPiezaManual(nombre: String) async -> Bool {
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else {
            errorMessage = "Escribe el nombre de la pieza."
            return false
        }
        guard !isWorking else { return false }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let nueva = try await service.crearPiezaManual(vehiculoId: vehiculoId, nombre: limpio)
            porRevisar.append(nueva)
            enResumen = false
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo agregar la pieza."
            return false
        }
    }

    /// Vuelve a leer una pieza para reflejar fotos recién subidas o borradas.
    func recargar(piezaId: String) async {
        do {
            let actualizada = try await service.fetchPieza(id: piezaId)
            if let indice = porRevisar.firstIndex(where: { $0.id == piezaId }) {
                porRevisar[indice] = actualizada
            }
            if let indice = aceptadas.firstIndex(where: { $0.id == piezaId }) {
                aceptadas[indice] = actualizada
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo actualizar la pieza."
        }
    }

    /// Confirma en lote las piezas aceptadas. Las que no tienen precio o condición quedan por confirmar.
    func confirmar() async {
        guard puedeConfirmar else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            resultadoConfirmacion = try await service.confirmarVerificacion(
                vehiculoId: vehiculoId,
                piezasIds: aceptadas.map(\.id)
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo confirmar la verificación."
        }
    }
}
