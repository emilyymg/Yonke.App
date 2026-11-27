import Foundation

// MARK: - Protocolo
/// Contrato de borradores y publicaciones. Hoy lo implementa `MockPublicacionService`.
///
/// Endpoints esperados (backend):
/// - GET    /api/borradores                  → borradores abiertos del usuario
/// - POST   /api/borradores {pieza_id}       → crea borrador con título y descripción sugeridos
/// - PUT    /api/borradores/:id              → guarda cambios (y `listo_para_publicar` si aplica)
/// - POST   /api/borradores/:id/publicar     → publicar_borrador()
/// - DELETE /api/borradores/:id              → estado `descartado` (sin borrado físico)
/// - GET    /api/publicaciones/mias?estado=  → activa | pausada | vendida

protocol PublicacionServiceProtocol {
    func fetchBorradores() async throws -> [Borrador]
    /// Borradores descartados (`GET /api/borradores?estado=descartado`).
    func fetchBorradoresDescartados() async throws -> [Borrador]
    /// Con `estado: nil` devuelve activa | pausada | vendida. `.eliminada` lista las eliminadas.
    func fetchPublicaciones(estado: EstadoPublicacion?) async throws -> [Publicacion]
    func crearBorrador(piezaId: String) async throws -> Borrador
    func actualizarBorrador(id: String, cambios: BorradorCambios) async throws -> Borrador
    func publicar(borradorId: String) async throws -> Publicacion
    func descartarBorrador(id: String) async throws -> Borrador
    /// Devuelve un borrador descartado a Borradores (`descartado` → `en_edicion`).
    func reabrirBorrador(id: String) async throws -> Borrador
    /// Pausar (activa → pausada), reactivar (pausada/eliminada → activa) o eliminar (activa/pausada → eliminada).
    func cambiarEstadoPublicacion(id: String, nuevo: EstadoPublicacion) async throws -> Publicacion
}

// MARK: - Errores de dominio

enum PublicacionError: LocalizedError {
    case borradorNoEncontrado
    case borradorNoEditable
    case borradorAbierto
    case publicacionVigente
    case piezaNoDisponible
    case borradorNoListo
    case faltanDatos
    case publicacionNoEncontrada
    case transicionNoPermitida(desde: EstadoPublicacion, hacia: EstadoPublicacion)

    var errorDescription: String? {
        switch self {
        case .borradorNoEncontrado:
            return "El borrador no existe."
        case .borradorNoEditable:
            return "Este borrador ya no se puede editar."
        case .borradorAbierto:
            return "Esta pieza ya tiene un borrador abierto."
        case .publicacionVigente:
            return "Esta pieza ya tiene una publicación activa o pausada."
        case .piezaNoDisponible:
            return "La pieza debe estar disponible para publicarse."
        case .borradorNoListo:
            return "El borrador no está listo para publicar."
        case .faltanDatos:
            return "Título y precio son obligatorios para publicar."
        case .publicacionNoEncontrada:
            return "La publicación no existe."
        case .transicionNoPermitida(let desde, let hacia):
            return "No se puede pasar de \(desde.label) a \(hacia.label)."
        }
    }
}

// MARK: - Implementación remota
/// Borradores y publicaciones de la app de yonqueros:
/// `/api/borradores` (CRUD, publicar, descartar) y `/api/publicaciones/mias`.
/// El marketplace público (`/api/publicaciones` sin "mias") no lo usa la app.

final class RemotePublicacionService: PublicacionServiceProtocol {

    nonisolated static let shared = RemotePublicacionService()

    private let api: APIClient

    private init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: Lectura

    func fetchBorradores() async throws -> [Borrador] {
        try await api.request(.get, APIPath.borradores)
    }

    func fetchBorradoresDescartados() async throws -> [Borrador] {
        try await api.request(.get, "\(APIPath.borradores)?estado=descartado")
    }

    func fetchPublicaciones(estado: EstadoPublicacion?) async throws -> [Publicacion] {
        var path = APIPath.publicacionesMias
        if let estado {
            path += "?estado=\(estado.rawValue)"
        }
        return try await api.request(.get, path)
    }

    // MARK: Escritura

    func crearBorrador(piezaId: String) async throws -> Borrador {
        try await api.request(.post, APIPath.borradores, body: CrearBorradorRequest(piezaId: piezaId))
    }

    func actualizarBorrador(id: String, cambios: BorradorCambios) async throws -> Borrador {
        try await api.request(.put, APIPath.borrador(id), body: ActualizarBorradorRequest(cambios: cambios))
    }

    /// El backend responde solo con el id de la publicación; la leemos de "mias" para devolver el modelo completo.
    func publicar(borradorId: String) async throws -> Publicacion {
        let respuesta: PublicarRespuesta = try await api.request(.post, APIPath.publicarBorrador(borradorId))
        let publicaciones = try await fetchPublicaciones(estado: nil)
        guard let publicacion = publicaciones.first(where: { $0.id == respuesta.publicacionId }) else {
            throw APIError.invalidResponse
        }
        return publicacion
    }

    func descartarBorrador(id: String) async throws -> Borrador {
        let _: MensajeRespuesta = try await api.request(.delete, APIPath.borrador(id))
        return try await api.request(.get, APIPath.borrador(id))
    }

    func reabrirBorrador(id: String) async throws -> Borrador {
        try await api.request(.post, APIPath.reabrirBorrador(id))
    }

    func cambiarEstadoPublicacion(id: String, nuevo: EstadoPublicacion) async throws -> Publicacion {
        try await api.request(.post, APIPath.estadoPublicacion(id),
                              body: CambiarEstadoPublicacionRequest(estado: nuevo))
    }

    // MARK: Cuerpos y respuestas

    private struct CambiarEstadoPublicacionRequest: Encodable {
        let estado: EstadoPublicacion
    }

    private struct CrearBorradorRequest: Encodable {
        let piezaId: String

        enum CodingKeys: String, CodingKey {
            case piezaId = "pieza_id"
        }
    }

    private struct ActualizarBorradorRequest: Encodable {
        let titulo: String
        let descripcion: String
        let precioPublico: Double?
        let condicionPublicada: CondicionPieza?
        let fotosMarketplace: [String]
        let marcarListo: Bool

        init(cambios: BorradorCambios) {
            self.titulo = cambios.titulo
            self.descripcion = cambios.descripcion
            self.precioPublico = cambios.precio
            self.condicionPublicada = cambios.condicion
            self.fotosMarketplace = cambios.fotosMarketplace
            self.marcarListo = cambios.marcarListo
        }

        enum CodingKeys: String, CodingKey {
            case titulo
            case descripcion
            case precioPublico = "precio_publico"
            case condicionPublicada = "condicion_publicada"
            case fotosMarketplace = "fotos_marketplace"
            case marcarListo = "marcar_listo"
        }
    }

    private struct PublicarRespuesta: Decodable {
        let publicacionId: String
    }

    private struct MensajeRespuesta: Decodable {
        let message: String
    }
}

// MARK: - Mock

final class MockPublicacionService: PublicacionServiceProtocol {

    nonisolated static let shared = MockPublicacionService()

    private let inventario: InventoryServiceProtocol
    private var borradores: [Borrador]
    private var publicaciones: [Publicacion]
    private var contador = 0

    private init(inventario: InventoryServiceProtocol = MockInventoryService.shared) {
        self.inventario = inventario

        let fotoMotor = URL(string: "https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&auto=format&fit=crop&w=320")
        let fotoAlternador = URL(string: "https://images.unsplash.com/photo-1517524206127-48bbd363f3d7?q=80&auto=format&fit=crop&w=320")

        borradores = [
            Borrador(id: "b-1", piezaId: "pz-1",
                     titulo: "Motor completo 2.0L Toyota Corolla 2015",
                     descripcionMarketplace: "80,000 km, compresión excelente. Probado.",
                     precioPublico: 1500, condicionPublicada: .seminuevo,
                     fotosMarketplace: ["f-1"], estado: .enEdicion,
                     piezaNombre: "Motor completo 2.0L", piezaSku: "YNQ-TCO15-1-MOT1",
                     vehiculoTitulo: "2015 Toyota Corolla", fotoThumbUrl: fotoMotor)
        ]

        publicaciones = [
            Publicacion(id: "p-1", piezaId: "pz-4",
                        titulo: "Puerta delantera derecha Honda Civic 2018",
                        descripcion: "Color negro, sin rayones.", precio: 250,
                        condicion: .seminuevo, estado: .activa, vistas: 12,
                        fechaPublicacion: Date().addingTimeInterval(-86_400),
                        piezaNombre: "Puerta delantera derecha", piezaSku: "YNQ-HCI18-1-PUE4",
                        vehiculoTitulo: "2018 Honda Civic", fotoThumbUrl: fotoAlternador),
            Publicacion(id: "p-2", piezaId: "pz-6",
                        titulo: "Diferencial trasero Ford F-150 2012",
                        descripcion: "Buen estado general.", precio: 310,
                        condicion: .usado, estado: .pausada, vistas: 4,
                        fechaPublicacion: Date().addingTimeInterval(-3 * 86_400),
                        piezaNombre: "Diferencial trasero", piezaSku: "YNQ-FF12-1-DIF6",
                        vehiculoTitulo: "2012 Ford F-150", fotoThumbUrl: fotoAlternador),
            Publicacion(id: "p-3", piezaId: "pz-5",
                        titulo: "Transmisión automática Ford F-150 2012",
                        descripcion: "Requiere servicio de banda.", precio: 400,
                        condicion: .refaccionado, estado: .vendida, vistas: 30,
                        fechaPublicacion: Date().addingTimeInterval(-10 * 86_400),
                        piezaNombre: "Transmisión automática", piezaSku: "YNQ-FF12-1-TRA5",
                        vehiculoTitulo: "2012 Ford F-150", fotoThumbUrl: nil)
        ]
    }

    // MARK: - Lectura

    func fetchBorradores() async throws -> [Borrador] {
        try await delay()
        return borradores.filter { $0.estado.estaAbierto }
    }

    func fetchBorradoresDescartados() async throws -> [Borrador] {
        try await delay()
        return borradores.filter { $0.estado == .descartado }
    }

    func fetchPublicaciones(estado: EstadoPublicacion?) async throws -> [Publicacion] {
        try await delay()
        let visibles = publicaciones.filter { publicacion in
            if let estado { return publicacion.estado == estado }
            return EstadoPublicacion.filtrables.contains(publicacion.estado)
        }
        return visibles.sorted { ($0.fechaPublicacion ?? .distantPast) > ($1.fechaPublicacion ?? .distantPast) }
    }

    // MARK: - Escritura

    func crearBorrador(piezaId: String) async throws -> Borrador {
        try await delay()

        guard !borradores.contains(where: { $0.piezaId == piezaId && $0.estado.estaAbierto }) else {
            throw PublicacionError.borradorAbierto
        }
        guard !publicaciones.contains(where: { $0.piezaId == piezaId && ($0.estado == .activa || $0.estado == .pausada) }) else {
            throw PublicacionError.publicacionVigente
        }

        let pieza = try await inventario.fetchPieza(id: piezaId)
        guard pieza.estado == .disponible else { throw PublicacionError.piezaNoDisponible }

        let vehiculo = try await inventario.fetchVehiculos().first { $0.id == pieza.vehiculoId }
        let vehiculoTitulo = vehiculo?.titulo

        contador += 1
        let borrador = Borrador(
            id: "b-\(contador + 100)",
            piezaId: piezaId,
            titulo: [pieza.nombre, vehiculoTitulo].compactMap { $0 }.joined(separator: " "),
            descripcionMarketplace: pieza.descripcion ?? "",
            precioPublico: pieza.precioVenta,
            condicionPublicada: pieza.condicion,
            fotosMarketplace: pieza.fotoPrincipal.map { [$0.id] } ?? [],
            estado: .pendiente,
            piezaNombre: pieza.nombre,
            piezaSku: pieza.sku,
            vehiculoTitulo: vehiculoTitulo,
            fotoThumbUrl: pieza.fotoPrincipal?.thumbUrl
        )
        borradores.append(borrador)
        return borrador
    }

    func actualizarBorrador(id: String, cambios: BorradorCambios) async throws -> Borrador {
        try await delay()

        guard let indice = borradores.firstIndex(where: { $0.id == id }) else {
            throw PublicacionError.borradorNoEncontrado
        }
        let actual = borradores[indice]
        guard actual.estado.estaAbierto else { throw PublicacionError.borradorNoEditable }

        let titulo = cambios.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        if cambios.marcarListo {
            guard !titulo.isEmpty, let precio = cambios.precio, precio > 0 else {
                throw PublicacionError.faltanDatos
            }
        }

        let actualizado = Borrador(
            id: actual.id,
            piezaId: actual.piezaId,
            titulo: titulo.isEmpty ? nil : titulo,
            descripcionMarketplace: cambios.descripcion,
            precioPublico: cambios.precio,
            condicionPublicada: cambios.condicion,
            fotosMarketplace: cambios.fotosMarketplace,
            estado: cambios.marcarListo ? .listoParaPublicar : .enEdicion,
            piezaNombre: actual.piezaNombre,
            piezaSku: actual.piezaSku,
            vehiculoTitulo: actual.vehiculoTitulo,
            fotoThumbUrl: actual.fotoThumbUrl
        )
        borradores[indice] = actualizado
        return actualizado
    }

    func publicar(borradorId: String) async throws -> Publicacion {
        try await delay()

        guard let indice = borradores.firstIndex(where: { $0.id == borradorId }) else {
            throw PublicacionError.borradorNoEncontrado
        }
        let borrador = borradores[indice]
        guard borrador.estado == .listoParaPublicar else { throw PublicacionError.borradorNoListo }
        guard let titulo = borrador.titulo, let precio = borrador.precioPublico, precio > 0 else {
            throw PublicacionError.faltanDatos
        }

        let pieza = try await inventario.fetchPieza(id: borrador.piezaId)
        guard pieza.estado == .disponible else { throw PublicacionError.piezaNoDisponible }
        guard !publicaciones.contains(where: { $0.piezaId == borrador.piezaId && ($0.estado == .activa || $0.estado == .pausada) }) else {
            throw PublicacionError.publicacionVigente
        }

        contador += 1
        let publicacion = Publicacion(
            id: "p-\(contador + 100)",
            piezaId: borrador.piezaId,
            titulo: titulo,
            descripcion: borrador.descripcionMarketplace,
            precio: precio,
            condicion: borrador.condicionPublicada,
            estado: .activa,
            vistas: 0,
            fechaPublicacion: Date(),
            piezaNombre: borrador.piezaNombre,
            piezaSku: borrador.piezaSku,
            vehiculoTitulo: borrador.vehiculoTitulo,
            fotoThumbUrl: borrador.fotoThumbUrl
        )
        publicaciones.append(publicacion)

        borradores[indice] = Borrador(
            id: borrador.id, piezaId: borrador.piezaId,
            titulo: borrador.titulo, descripcionMarketplace: borrador.descripcionMarketplace,
            precioPublico: borrador.precioPublico, condicionPublicada: borrador.condicionPublicada,
            fotosMarketplace: borrador.fotosMarketplace, estado: .publicado,
            piezaNombre: borrador.piezaNombre, piezaSku: borrador.piezaSku,
            vehiculoTitulo: borrador.vehiculoTitulo, fotoThumbUrl: borrador.fotoThumbUrl
        )
        return publicacion
    }

    func descartarBorrador(id: String) async throws -> Borrador {
        try await delay()

        guard let indice = borradores.firstIndex(where: { $0.id == id }) else {
            throw PublicacionError.borradorNoEncontrado
        }
        let actual = borradores[indice]
        guard actual.estado.estaAbierto else { throw PublicacionError.borradorNoEditable }

        let descartado = Borrador(
            id: actual.id, piezaId: actual.piezaId,
            titulo: actual.titulo, descripcionMarketplace: actual.descripcionMarketplace,
            precioPublico: actual.precioPublico, condicionPublicada: actual.condicionPublicada,
            fotosMarketplace: actual.fotosMarketplace, estado: .descartado,
            piezaNombre: actual.piezaNombre, piezaSku: actual.piezaSku,
            vehiculoTitulo: actual.vehiculoTitulo, fotoThumbUrl: actual.fotoThumbUrl
        )
        borradores[indice] = descartado
        return descartado
    }

    func reabrirBorrador(id: String) async throws -> Borrador {
        try await delay()

        guard let indice = borradores.firstIndex(where: { $0.id == id }) else {
            throw PublicacionError.borradorNoEncontrado
        }
        let actual = borradores[indice]
        guard actual.estado == .descartado else { throw PublicacionError.borradorNoEditable }

        let pieza = try await inventario.fetchPieza(id: actual.piezaId)
        guard pieza.estado == .disponible else { throw PublicacionError.piezaNoDisponible }
        guard !borradores.contains(where: { $0.piezaId == actual.piezaId && $0.estado.estaAbierto }) else {
            throw PublicacionError.borradorAbierto
        }

        let reabierto = Borrador(
            id: actual.id, piezaId: actual.piezaId,
            titulo: actual.titulo, descripcionMarketplace: actual.descripcionMarketplace,
            precioPublico: actual.precioPublico, condicionPublicada: actual.condicionPublicada,
            fotosMarketplace: actual.fotosMarketplace, estado: .enEdicion,
            piezaNombre: actual.piezaNombre, piezaSku: actual.piezaSku,
            vehiculoTitulo: actual.vehiculoTitulo, fotoThumbUrl: actual.fotoThumbUrl
        )
        borradores[indice] = reabierto
        return reabierto
    }

    // MARK: - Estado de publicación

    func cambiarEstadoPublicacion(id: String, nuevo: EstadoPublicacion) async throws -> Publicacion {
        try await delay()
        guard let indice = publicaciones.firstIndex(where: { $0.id == id }) else {
            throw PublicacionError.publicacionNoEncontrada
        }
        let actual = publicaciones[indice]
        let permitidos: [EstadoPublicacion: [EstadoPublicacion]] = [
            .activa: [.pausada, .eliminada],
            .pausada: [.activa, .eliminada],
            .eliminada: [.activa]
        ]
        guard permitidos[actual.estado]?.contains(nuevo) == true else {
            throw PublicacionError.transicionNoPermitida(desde: actual.estado, hacia: nuevo)
        }
        if nuevo == .activa, publicaciones.contains(where: {
            $0.id != id && $0.piezaId == actual.piezaId && ($0.estado == .activa || $0.estado == .pausada)
        }) {
            throw PublicacionError.publicacionVigente
        }
        let actualizada = actual.conEstado(nuevo)
        publicaciones[indice] = actualizada
        return actualizada
    }

    // MARK: - Venta

    /// Lo hace `procesar_venta` en la base: cierra la publicación vigente de la pieza.
    /// Lo llama el mock de ventas antes de marcar la pieza como vendida.
    func cerrarPorVenta(piezaId: String) {
        for indice in publicaciones.indices
        where publicaciones[indice].piezaId == piezaId
            && (publicaciones[indice].estado == .activa || publicaciones[indice].estado == .pausada) {
            publicaciones[indice] = publicaciones[indice].conEstado(.vendida)
        }
    }

    // MARK: - Helpers

    private func delay() async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }
}
