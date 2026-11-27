import Foundation

// MARK: - Protocolo
/// Contrato del inventario. Hoy lo implementa `MockInventoryService`.
/// Cuando el backend exponga los endpoints, se añade una implementación real
/// sobre `APIClient` sin tocar los ViewModels.
///
/// Endpoints esperados (plan de la app):
/// - GET  /api/vehiculos, GET /api/piezas?estado=, GET /api/piezas/:id
/// - POST /api/vehiculos                 → registrar_vehiculo_con_piezas
/// - POST /api/piezas/:id/confirmar      → precio + condición + cambiar_estado_pieza('disponible')
/// - POST /api/piezas/:id/estado         → cambiar_estado_pieza
/// - Catálogo de marcas y modelos (endpoint por definir)

protocol InventoryServiceProtocol {
    func fetchVehiculos() async throws -> [VehiculoInventario]
    func fetchPiezas(estado: EstadoPieza?) async throws -> [PiezaInventario]
    func fetchPieza(id: String) async throws -> PiezaInventario
    /// Búsqueda exacta por SKU (`GET /api/piezas?sku=`). Lo usa el escáner.
    func fetchPiezaPorSku(_ sku: String) async throws -> PiezaInventario
    func fetchMarcas() async throws -> [MarcaVehiculo]
    func fetchModelos(marcaId: String) async throws -> [ModeloVehiculo]
    func registrarVehiculo(modeloId: String, anio: Int) async throws -> RegistroVehiculoResultado
    /// Baja lógica del vehículo; el backend también elimina sus publicaciones.
    func eliminarVehiculo(id: String) async throws
    func confirmarPieza(id: String, precioVenta: Double, condicion: CondicionPieza) async throws -> PiezaInventario
    func cambiarEstado(piezaId: String, nuevo: EstadoPieza, motivo: String?) async throws -> PiezaInventario
    /// Todas las piezas de un vehículo, en orden de catálogo.
    func fetchPiezasDeVehiculo(vehiculoId: String) async throws -> [PiezaInventario]
    /// Edita características. Los valores nil no cambian.
    func actualizarPieza(id: String, nombre: String?, descripcion: String?,
                         condicion: CondicionPieza?, precioVenta: Double?) async throws -> PiezaInventario
    /// Descarta una pieza por confirmar: se borra si no tiene historial, si no pasa a descartado.
    func descartarPieza(id: String) async throws
    /// Crea una pieza fuera de catálogo para el vehículo.
    func crearPiezaManual(vehiculoId: String, nombre: String, descripcion: String?,
                          condicion: CondicionPieza?, precioVenta: Double?) async throws -> PiezaInventario
    /// Pasa a disponible las piezas con precio y condición. El resto queda por confirmar.
    func confirmarVerificacion(vehiculoId: String, piezasIds: [String]) async throws -> ResultadoVerificacion
}

extension InventoryServiceProtocol {
    func crearPiezaManual(vehiculoId: String, nombre: String) async throws -> PiezaInventario {
        try await crearPiezaManual(vehiculoId: vehiculoId, nombre: nombre,
                                   descripcion: nil, condicion: nil, precioVenta: nil)
    }
}

// MARK: - Errores de dominio

enum InventoryError: LocalizedError {
    case notFound
    case skuNoEncontrado(String)
    case transicionNoPermitida(desde: EstadoPieza, hacia: EstadoPieza)
    case precioInvalido
    case modeloInvalido
    case piezaVendida

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "La pieza no existe."
        case .skuNoEncontrado(let sku):
            return "No hay una pieza con el SKU \(sku)."
        case .transicionNoPermitida(let desde, let hacia):
            return "No se puede pasar de \(desde.label) a \(hacia.label)."
        case .precioInvalido:
            return "El precio debe ser mayor a cero."
        case .modeloInvalido:
            return "Selecciona un modelo del catálogo."
        case .piezaVendida:
            return "Una pieza vendida no se puede editar."
        }
    }
}

// MARK: - Implementación remota
/// Inventario sobre `/api/vehiculos`, `/api/piezas` y `/api/catalogos`.
/// Los JSON del backend ya coinciden con los modelos (snake_case → camelCase en `APIClient`).
/// El yonque sale del token, así que ninguna petición lo envía.

final class RemoteInventoryService: InventoryServiceProtocol {

    nonisolated static let shared = RemoteInventoryService()

    private let api: APIClient

    private init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: Lectura

    func fetchVehiculos() async throws -> [VehiculoInventario] {
        try await api.request(.get, APIPath.vehiculos)
    }

    func fetchPiezas(estado: EstadoPieza?) async throws -> [PiezaInventario] {
        var path = APIPath.piezas
        if let estado {
            path += "?estado=\(estado.rawValue)"
        }
        return try await api.request(.get, path)
    }

    func fetchPieza(id: String) async throws -> PiezaInventario {
        try await api.request(.get, APIPath.pieza(id))
    }

    func fetchPiezaPorSku(_ sku: String) async throws -> PiezaInventario {
        let valor = sku.trimmingCharacters(in: .whitespacesAndNewlines)
        let permitidos = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
        let codificado = valor.addingPercentEncoding(withAllowedCharacters: permitidos) ?? valor
        let piezas: [PiezaInventario] = try await api.request(.get, "\(APIPath.piezas)?sku=\(codificado)")
        guard let pieza = piezas.first else { throw InventoryError.skuNoEncontrado(valor) }
        return pieza
    }

    func fetchMarcas() async throws -> [MarcaVehiculo] {
        try await api.request(.get, APIPath.marcas)
    }

    func fetchModelos(marcaId: String) async throws -> [ModeloVehiculo] {
        try await api.request(.get, APIPath.modelos(marcaId: marcaId))
    }

    // MARK: Escritura

    func registrarVehiculo(modeloId: String, anio: Int) async throws -> RegistroVehiculoResultado {
        try await api.request(.post, APIPath.vehiculos,
                              body: RegistrarVehiculoRequest(modeloId: modeloId, anio: anio))
    }

    func eliminarVehiculo(id: String) async throws {
        let _: MensajeRespuesta = try await api.request(.delete, APIPath.vehiculo(id))
    }

    func confirmarPieza(id: String, precioVenta: Double, condicion: CondicionPieza) async throws -> PiezaInventario {
        guard precioVenta > 0 else { throw InventoryError.precioInvalido }
        return try await api.request(.post, APIPath.confirmarPieza(id),
                                     body: ConfirmarPiezaRequest(precioVenta: precioVenta, condicion: condicion))
    }

    func cambiarEstado(piezaId: String, nuevo: EstadoPieza, motivo: String?) async throws -> PiezaInventario {
        try await api.request(.post, APIPath.estadoPieza(piezaId),
                              body: CambiarEstadoRequest(estado: nuevo, motivo: motivo))
    }

    func fetchPiezasDeVehiculo(vehiculoId: String) async throws -> [PiezaInventario] {
        try await api.request(.get, "\(APIPath.piezas)?vehiculo_id=\(vehiculoId)")
    }

    func actualizarPieza(id: String, nombre: String?, descripcion: String?,
                         condicion: CondicionPieza?, precioVenta: Double?) async throws -> PiezaInventario {
        try await api.request(.patch, APIPath.pieza(id),
                              body: ActualizarPiezaRequest(nombre: nombre, descripcion: descripcion,
                                                           condicion: condicion, precioVenta: precioVenta))
    }

    func descartarPieza(id: String) async throws {
        let _: RespuestaDescarte = try await api.request(.post, APIPath.descartarPieza(id))
    }

    func crearPiezaManual(vehiculoId: String, nombre: String, descripcion: String?,
                          condicion: CondicionPieza?, precioVenta: Double?) async throws -> PiezaInventario {
        try await api.request(.post, APIPath.piezas,
                              body: CrearPiezaRequest(vehiculoId: vehiculoId, nombre: nombre,
                                                      descripcion: descripcion, condicion: condicion,
                                                      precioVenta: precioVenta))
    }

    func confirmarVerificacion(vehiculoId: String, piezasIds: [String]) async throws -> ResultadoVerificacion {
        try await api.request(.post, APIPath.verificacionVehiculo(vehiculoId),
                              body: ConfirmarVerificacionRequest(piezasIds: piezasIds))
    }

    private struct MensajeRespuesta: Decodable {
        let message: String
    }

    private struct ConfirmarPiezaRequest: Encodable {
        let precioVenta: Double
        let condicion: CondicionPieza

        enum CodingKeys: String, CodingKey {
            case precioVenta = "precio_venta"
            case condicion
        }
    }

    private struct CambiarEstadoRequest: Encodable {
        let estado: EstadoPieza
        let motivo: String?
    }
}

// MARK: - Mock

final class MockInventoryService: InventoryServiceProtocol {

    nonisolated static let shared = MockInventoryService()

    private var vehiculos: [VehiculoInventario]
    private var piezas: [PiezaInventario]
    private let marcas: [MarcaVehiculo]
    private let modelos: [ModeloVehiculo]
    private var contadorVehiculos: Int

    private init() {
        marcas = [
            MarcaVehiculo(id: "mar-toyota", nombre: "Toyota"),
            MarcaVehiculo(id: "mar-honda", nombre: "Honda"),
            MarcaVehiculo(id: "mar-ford", nombre: "Ford"),
            MarcaVehiculo(id: "mar-nissan", nombre: "Nissan")
        ]
        modelos = [
            ModeloVehiculo(id: "mod-corolla", marcaId: "mar-toyota", nombre: "Corolla"),
            ModeloVehiculo(id: "mod-camry", marcaId: "mar-toyota", nombre: "Camry"),
            ModeloVehiculo(id: "mod-civic", marcaId: "mar-honda", nombre: "Civic"),
            ModeloVehiculo(id: "mod-f150", marcaId: "mar-ford", nombre: "F-150"),
            ModeloVehiculo(id: "mod-tsuru", marcaId: "mar-nissan", nombre: "Tsuru")
        ]

        vehiculos = [
            VehiculoInventario(id: "veh-1", marca: "Toyota", modelo: "Corolla", anio: 2015, vin: "1NXBR12E35Z123456"),
            VehiculoInventario(id: "veh-2", marca: "Honda", modelo: "Civic", anio: 2018, vin: "2HGES165X8H512345"),
            VehiculoInventario(id: "veh-3", marca: "Ford", modelo: "F-150", anio: 2012, vin: "1FTRF12345NB00001")
        ]
        contadorVehiculos = vehiculos.count

        let motor = "photo-1486006920555-c77dce18193b"
        let alternador = "photo-1517524206127-48bbd363f3d7"

        piezas = [
            PiezaInventario(id: "pz-1", vehiculoId: "veh-1", sku: "YNQ-TCO15-1-MOT1",
                            nombre: "Motor completo 2.0L", descripcion: "80,000 km, compresión excelente.",
                            condicion: .seminuevo, precioVenta: 1500, estado: .disponible,
                            fotos: [Self.foto("f-1", orden: 0, principal: true, photoID: motor)]),
            PiezaInventario(id: "pz-2", vehiculoId: "veh-1", sku: "YNQ-TCO15-1-ALT2",
                            nombre: "Alternador", descripcion: nil,
                            condicion: nil, precioVenta: nil, estado: .porConfirmar,
                            fotos: []),
            PiezaInventario(id: "pz-3", vehiculoId: "veh-2", sku: "YNQ-HCI18-1-ALT1",
                            nombre: "Alternador de corriente", descripcion: "Funcionando, probado.",
                            condicion: .usado, precioVenta: 120, estado: .reservado,
                            fotos: [Self.foto("f-2", orden: 0, principal: true, photoID: alternador)]),
            PiezaInventario(id: "pz-4", vehiculoId: "veh-2", sku: "YNQ-HCI18-1-PUE4",
                            nombre: "Puerta delantera derecha", descripcion: "Color negro, sin rayones.",
                            condicion: .seminuevo, precioVenta: 250, estado: .disponible,
                            fotos: [Self.foto("f-3", orden: 0, principal: true, photoID: motor)]),
            PiezaInventario(id: "pz-5", vehiculoId: "veh-3", sku: "YNQ-FF12-1-TRA5",
                            nombre: "Transmisión automática", descripcion: "Requiere servicio de banda.",
                            condicion: .refaccionado, precioVenta: 400, estado: .vendido,
                            fotos: []),
            PiezaInventario(id: "pz-6", vehiculoId: "veh-3", sku: "YNQ-FF12-1-DIF6",
                            nombre: "Diferencial trasero", descripcion: "Buen estado general.",
                            condicion: .usado, precioVenta: 310, estado: .disponible,
                            fotos: [
                                Self.foto("f-4", orden: 0, principal: true, photoID: alternador),
                                Self.foto("f-5", orden: 1, principal: false, photoID: motor)
                            ]),
            PiezaInventario(id: "pz-7", vehiculoId: "veh-3", sku: "YNQ-FF12-1-FAR7",
                            nombre: "Faro delantero izquierdo", descripcion: nil,
                            condicion: nil, precioVenta: nil, estado: .porConfirmar,
                            fotos: [])
        ]
    }

    // MARK: - Lectura

    func fetchVehiculos() async throws -> [VehiculoInventario] {
        try await delay()
        return vehiculos
    }

    func fetchPiezas(estado: EstadoPieza?) async throws -> [PiezaInventario] {
        try await delay()
        let coincidentes = estado.map { e in piezas.filter { $0.estado == e } } ?? piezas
        return coincidentes.map(salida)
    }

    func fetchPieza(id: String) async throws -> PiezaInventario {
        try await delay()
        return salida(try pieza(id: id))
    }

    func fetchPiezaPorSku(_ sku: String) async throws -> PiezaInventario {
        try await delay()
        let buscado = sku.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let pieza = piezas.first(where: { $0.sku?.uppercased() == buscado }) else {
            throw InventoryError.skuNoEncontrado(buscado)
        }
        return salida(pieza)
    }

    func fetchMarcas() async throws -> [MarcaVehiculo] {
        try await delay()
        return marcas
    }

    func fetchModelos(marcaId: String) async throws -> [ModeloVehiculo] {
        try await delay()
        return modelos.filter { $0.marcaId == marcaId }
    }

    // MARK: - Escritura

    func registrarVehiculo(modeloId: String, anio: Int) async throws -> RegistroVehiculoResultado {
        try await delay()
        guard let modelo = modelos.first(where: { $0.id == modeloId }),
              let marca = marcas.first(where: { $0.id == modelo.marcaId }) else {
            throw InventoryError.modeloInvalido
        }

        contadorVehiculos += 1
        let vehiculoId = "veh-\(contadorVehiculos)"
        vehiculos.append(VehiculoInventario(id: vehiculoId, marca: marca.nombre,
                                            modelo: modelo.nombre, anio: anio, vin: nil))

        // Simula la plantilla de piezas que genera la base al registrar el vehículo.
        let plantilla = ["Motor", "Transmisión", "Alternador", "Faro delantero", "Puerta delantera"]
        for (indice, nombre) in plantilla.enumerated() {
            piezas.append(PiezaInventario(
                id: "pz-\(vehiculoId)-\(indice + 1)",
                vehiculoId: vehiculoId,
                sku: "YNQ-\(vehiculoId.uppercased())-\(indice + 1)",
                nombre: nombre, descripcion: nil,
                condicion: nil, precioVenta: nil, estado: .porConfirmar,
                fotos: []
            ))
        }

        return RegistroVehiculoResultado(vehiculoId: vehiculoId, piezasGeneradas: plantilla.count)
    }

    func eliminarVehiculo(id: String) async throws {
        try await delay()
        guard vehiculos.contains(where: { $0.id == id }) else { throw InventoryError.notFound }
        vehiculos.removeAll { $0.id == id }
        piezas.removeAll { $0.vehiculoId == id }
    }

    func fetchPiezasDeVehiculo(vehiculoId: String) async throws -> [PiezaInventario] {
        try await delay()
        return piezas.filter { $0.vehiculoId == vehiculoId }.map(salida)
    }

    func actualizarPieza(id: String, nombre: String?, descripcion: String?,
                         condicion: CondicionPieza?, precioVenta: Double?) async throws -> PiezaInventario {
        try await delay()
        let actual = try pieza(id: id)
        guard actual.estado != .vendido else { throw InventoryError.piezaVendida }

        // Igual que el backend: descripción vacía se guarda como nil.
        let nuevaDescripcion: String?
        if let descripcion { nuevaDescripcion = descripcion.isEmpty ? nil : descripcion } else { nuevaDescripcion = actual.descripcion }

        let actualizada = PiezaInventario(
            id: actual.id, vehiculoId: actual.vehiculoId, sku: actual.sku,
            nombre: nombre ?? actual.nombre,
            descripcion: nuevaDescripcion,
            condicion: condicion ?? actual.condicion,
            precioVenta: precioVenta ?? actual.precioVenta,
            estado: actual.estado,
            fotos: actual.fotos
        )
        reemplazar(actualizada)
        return salida(actualizada)
    }

    func descartarPieza(id: String) async throws {
        try await delay()
        let actual = try pieza(id: id)
        guard actual.estado == .porConfirmar else {
            throw InventoryError.transicionNoPermitida(desde: actual.estado, hacia: .descartado)
        }
        // El mock no tiene historial de fotos ni publicaciones: siempre borra.
        piezas.removeAll { $0.id == id }
    }

    func crearPiezaManual(vehiculoId: String, nombre: String, descripcion: String?,
                          condicion: CondicionPieza?, precioVenta: Double?) async throws -> PiezaInventario {
        try await delay()
        guard vehiculos.contains(where: { $0.id == vehiculoId }) else { throw InventoryError.notFound }
        let nuevaDescripcion = descripcion.flatMap { $0.isEmpty ? nil : $0 }
        let nueva = PiezaInventario(
            id: "pz-manual-\(UUID().uuidString.prefix(8))",
            vehiculoId: vehiculoId,
            sku: nil, nombre: nombre, descripcion: nuevaDescripcion,
            condicion: condicion, precioVenta: precioVenta, estado: .porConfirmar,
            fotos: []
        )
        piezas.append(nueva)
        return salida(nueva)
    }

    func confirmarVerificacion(vehiculoId: String, piezasIds: [String]) async throws -> ResultadoVerificacion {
        try await delay()
        var confirmadas = 0
        var pendientes: [String] = []
        for id in piezasIds {
            guard let actual = try? pieza(id: id), actual.estado == .porConfirmar, actual.vehiculoId == vehiculoId else {
                continue
            }
            if let precio = actual.precioVenta, precio > 0, actual.condicion != nil {
                reemplazar(actual.actualizando(estado: .disponible))
                confirmadas += 1
            } else {
                pendientes.append(id)
            }
        }
        return ResultadoVerificacion(confirmadas: confirmadas, pendientes: pendientes)
    }

    func confirmarPieza(id: String, precioVenta: Double, condicion: CondicionPieza) async throws -> PiezaInventario {
        try await delay()
        guard precioVenta > 0 else { throw InventoryError.precioInvalido }

        let actual = try pieza(id: id)
        guard actual.estado.puedeCambiarA(.disponible) else {
            throw InventoryError.transicionNoPermitida(desde: actual.estado, hacia: .disponible)
        }

        let actualizada = actual.actualizando(estado: .disponible, precioVenta: precioVenta, condicion: condicion)
        reemplazar(actualizada)
        return salida(actualizada)
    }

    func cambiarEstado(piezaId: String, nuevo: EstadoPieza, motivo: String?) async throws -> PiezaInventario {
        try await delay()
        let actual = try pieza(id: piezaId)
        guard actual.estado.puedeCambiarA(nuevo) else {
            throw InventoryError.transicionNoPermitida(desde: actual.estado, hacia: nuevo)
        }

        let actualizada = actual.actualizando(estado: nuevo)
        reemplazar(actualizada)
        return salida(actualizada)
    }

    // MARK: - Helpers

    /// Pieza tal como la ve la app: datos guardados más las fotos del almacén mock.
    private func salida(_ pieza: PiezaInventario) -> PiezaInventario {
        pieza.conFotos(MockFotoStore.shared.fotos(piezaId: pieza.id))
    }

    private func pieza(id: String) throws -> PiezaInventario {
        guard let pieza = piezas.first(where: { $0.id == id }) else {
            throw InventoryError.notFound
        }
        return pieza
    }

    private func reemplazar(_ pieza: PiezaInventario) {
        guard let indice = piezas.firstIndex(where: { $0.id == pieza.id }) else { return }
        piezas[indice] = pieza
    }

    private static func foto(_ id: String, orden: Int, principal: Bool, photoID: String) -> FotoPieza {
        func url(width: Int) -> URL? {
            URL(string: "https://images.unsplash.com/\(photoID)?q=80&auto=format&fit=crop&w=\(width)")
        }
        return FotoPieza(id: id, orden: orden, principal: principal,
                         thumbUrl: url(width: 320), mediumUrl: url(width: 1024))
    }

    private func delay() async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }
}
