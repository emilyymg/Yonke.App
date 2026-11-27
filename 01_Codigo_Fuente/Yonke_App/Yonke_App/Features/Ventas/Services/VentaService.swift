import Foundation

// MARK: - Protocolo
/// Contrato de ventas. Hoy lo implementa `MockVentaService`.
///
/// Endpoints esperados (backend):
/// - GET  /api/ventas                 → historial del yonque
/// - POST /api/ventas                 → procesar_venta(pieza_id, vendedor, comprador, precio, metodo, notas)
/// - POST /api/ventas/:id/devolver    → UPDATE ventas.estado = 'devuelta' (el trigger regresa la pieza a disponible)

protocol VentaServiceProtocol {
    func fetchVentas() async throws -> [Venta]
    func fetchVentaDePieza(piezaId: String) async throws -> Venta?
    func venderPieza(piezaId: String, input: VentaInput) async throws -> Venta
    func devolverVenta(id: String) async throws -> Venta
}

// MARK: - Errores de dominio

enum VentaError: LocalizedError {
    case notFound
    case precioInvalido
    case piezaNoVendible(EstadoPieza)
    case ventaVigente
    case noDevolvible

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "La venta no existe."
        case .precioInvalido:
            return "El precio final debe ser mayor a cero."
        case .piezaNoVendible(let estado):
            return "La pieza no se puede vender. Estado actual: \(estado.label)."
        case .ventaVigente:
            return "Esta pieza ya tiene una venta vigente."
        case .noDevolvible:
            return "Solo se pueden devolver ventas completadas."
        }
    }
}

// MARK: - Implementación remota
/// Ventas sobre `/api/ventas`. `procesar_venta` ocurre en el backend: cierra la publicación,
/// crea la venta y deja la pieza vendida. Las validaciones de negocio viven en el servidor.

final class RemoteVentaService: VentaServiceProtocol {

    nonisolated static let shared = RemoteVentaService()

    private let api: APIClient

    private init(api: APIClient = .shared) {
        self.api = api
    }

    func fetchVentas() async throws -> [Venta] {
        try await api.request(.get, APIPath.ventas)
    }

    func fetchVentaDePieza(piezaId: String) async throws -> Venta? {
        let ventas = try await fetchVentas()
        return ventas.first { $0.piezaId == piezaId && $0.estado.estaVigente }
    }

    func venderPieza(piezaId: String, input: VentaInput) async throws -> Venta {
        guard input.precioFinal > 0 else { throw VentaError.precioInvalido }
        return try await api.request(.post, APIPath.ventas,
                                     body: RegistrarVentaRequest(piezaId: piezaId, input: input))
    }

    func devolverVenta(id: String) async throws -> Venta {
        try await api.request(.post, APIPath.devolverVenta(id))
    }

    private struct RegistrarVentaRequest: Encodable {
        let piezaId: String
        let precioFinal: Double
        let metodoPago: MetodoPago
        let compradorNombre: String?
        let notas: String?

        init(piezaId: String, input: VentaInput) {
            self.piezaId = piezaId
            self.precioFinal = input.precioFinal
            self.metodoPago = input.metodoPago
            self.compradorNombre = Self.nilSiVacio(input.compradorNombre)
            self.notas = Self.nilSiVacio(input.notas)
        }

        private static func nilSiVacio(_ texto: String) -> String? {
            let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
            return limpio.isEmpty ? nil : limpio
        }

        enum CodingKeys: String, CodingKey {
            case piezaId = "pieza_id"
            case precioFinal = "precio_final"
            case metodoPago = "metodo_pago"
            case compradorNombre = "comprador_nombre"
            case notas
        }
    }
}

// MARK: - Mock

final class MockVentaService: VentaServiceProtocol {

    nonisolated static let shared = MockVentaService()

    private let inventario: InventoryServiceProtocol
    private let publicaciones: MockPublicacionService
    private var ventas: [Venta]
    private var contador = 0

    private init(inventario: InventoryServiceProtocol = MockInventoryService.shared,
                 publicaciones: MockPublicacionService = MockPublicacionService.shared) {
        self.inventario = inventario
        self.publicaciones = publicaciones

        let hace3Horas = Date().addingTimeInterval(-3 * 3600)
        let elMesPasado = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()

        ventas = [
            Venta(id: "v-1", piezaId: "pz-5", compradorNombre: "Carlos Ruiz", precioFinal: 400,
                  metodoPago: .efectivo, estado: .completada, notas: nil, fechaVenta: hace3Horas,
                  piezaNombre: "Transmisión automática", piezaSku: "YNQ-FF12-1-TRA5",
                  vehiculoTitulo: "2012 Ford F-150", fotoThumbUrl: nil),
            Venta(id: "v-2", piezaId: "pz-hist-2", compradorNombre: nil, precioFinal: 80,
                  metodoPago: .transferencia, estado: .devuelta, notas: "Faro no compatible",
                  fechaVenta: elMesPasado,
                  piezaNombre: "Faro delantero", piezaSku: "YNQ-TCO10-1-FAR3",
                  vehiculoTitulo: "2010 Toyota Corolla", fotoThumbUrl: nil)
        ]
    }

    // MARK: - Lectura

    func fetchVentas() async throws -> [Venta] {
        try await delay()
        return ventas.sorted { $0.fechaVenta > $1.fechaVenta }
    }

    func fetchVentaDePieza(piezaId: String) async throws -> Venta? {
        try await delay()
        return ventas.first { $0.piezaId == piezaId && $0.estado.estaVigente }
    }

    // MARK: - Escritura

    func venderPieza(piezaId: String, input: VentaInput) async throws -> Venta {
        try await delay()

        guard input.precioFinal > 0 else { throw VentaError.precioInvalido }

        let pieza = try await inventario.fetchPieza(id: piezaId)
        guard pieza.estado == .disponible || pieza.estado == .reservado else {
            throw VentaError.piezaNoVendible(pieza.estado)
        }
        guard !ventas.contains(where: { $0.piezaId == piezaId && $0.estado.estaVigente }) else {
            throw VentaError.ventaVigente
        }

        let vehiculoTitulo = try await inventario.fetchVehiculos().first { $0.id == pieza.vehiculoId }?.titulo

        // Mismo orden que procesar_venta: primero cerrar la publicación y luego marcar la pieza.
        publicaciones.cerrarPorVenta(piezaId: piezaId)
        _ = try await inventario.cambiarEstado(piezaId: piezaId, nuevo: .vendido, motivo: "Venta")

        contador += 1
        let venta = Venta(
            id: "v-\(contador + 100)",
            piezaId: piezaId,
            compradorNombre: input.compradorNombre.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            precioFinal: input.precioFinal,
            metodoPago: input.metodoPago,
            estado: .completada,
            notas: input.notas.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            fechaVenta: Date(),
            piezaNombre: pieza.nombre,
            piezaSku: pieza.sku,
            vehiculoTitulo: vehiculoTitulo,
            fotoThumbUrl: pieza.fotoPrincipal?.thumbUrl
        )
        ventas.append(venta)
        return venta
    }

    func devolverVenta(id: String) async throws -> Venta {
        try await delay()

        guard let indice = ventas.firstIndex(where: { $0.id == id }) else {
            throw VentaError.notFound
        }
        let actual = ventas[indice]
        guard actual.estado == .completada else { throw VentaError.noDevolvible }

        // El trigger de la base regresa la pieza a disponible. La publicación queda en vendida.
        _ = try await inventario.cambiarEstado(piezaId: actual.piezaId, nuevo: .disponible, motivo: "Venta devuelta")

        let devuelta = actual.conEstado(.devuelta)
        ventas[indice] = devuelta
        return devuelta
    }

    // MARK: - Helpers

    private func delay() async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
