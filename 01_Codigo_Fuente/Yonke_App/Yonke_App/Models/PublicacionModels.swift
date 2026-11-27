import Foundation

// MARK: - Estado de borrador
/// Valores de `borradores_publicacion.estado`.

enum EstadoBorrador: String, Codable, CaseIterable, Identifiable, Hashable {
    case pendiente
    case enEdicion = "en_edicion"
    case listoParaPublicar = "listo_para_publicar"
    case publicado
    case descartado

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pendiente:          return "Pendiente"
        case .enEdicion:          return "En edición"
        case .listoParaPublicar:  return "Listo para publicar"
        case .publicado:          return "Publicado"
        case .descartado:         return "Descartado"
        }
    }

    /// Un borrador abierto puede editarse, publicarse o descartarse.
    var estaAbierto: Bool {
        self == .pendiente || self == .enEdicion || self == .listoParaPublicar
    }
}

// MARK: - Estado de publicación
/// Valores de `publicaciones.estado`. El filtro de la app cubre activa, pausada y vendida.

enum EstadoPublicacion: String, Codable, CaseIterable, Identifiable, Hashable {
    case activa
    case pausada
    case vendida
    case eliminada
    case expirada

    var id: String { rawValue }

    var label: String {
        switch self {
        case .activa:    return "Activa"
        case .pausada:   return "Pausada"
        case .vendida:   return "Vendida"
        case .eliminada: return "Eliminada"
        case .expirada:  return "Expirada"
        }
    }

    /// Estados que muestra el filtro de la pestaña Publicaciones.
    static let filtrables: [EstadoPublicacion] = [.activa, .pausada, .vendida]
}

// MARK: - Borrador

struct Borrador: Codable, Identifiable, Hashable {
    let id: String
    let piezaId: String
    let titulo: String?
    let descripcionMarketplace: String?
    let precioPublico: Double?
    let condicionPublicada: CondicionPieza?
    /// Ids de `fotos` de la pieza que se publican. Nunca URLs.
    let fotosMarketplace: [String]
    let estado: EstadoBorrador

    // Datos de la pieza para listar sin pedir la pieza completa.
    let piezaNombre: String
    let piezaSku: String?
    let vehiculoTitulo: String?
    let fotoThumbUrl: URL?
    /// Motivo guardado al descartar el borrador (solo viene para descartados).
    var motivoDescarte: String? = nil
}

/// Cambios editables de un borrador. `marcarListo` pasa a `listo_para_publicar`.
struct BorradorCambios: Equatable {
    var titulo: String
    var descripcion: String
    var precio: Double?
    var condicion: CondicionPieza?
    var fotosMarketplace: [String]
    var marcarListo: Bool
}

// MARK: - Publicación

struct Publicacion: Codable, Identifiable, Hashable {
    let id: String
    let piezaId: String
    let titulo: String
    let descripcion: String?
    let precio: Double
    let condicion: CondicionPieza?
    let estado: EstadoPublicacion
    let vistas: Int
    let fechaPublicacion: Date?

    let piezaNombre: String
    let piezaSku: String?
    let vehiculoTitulo: String?
    let fotoThumbUrl: URL?

    func conEstado(_ nuevo: EstadoPublicacion) -> Publicacion {
        Publicacion(id: id, piezaId: piezaId, titulo: titulo, descripcion: descripcion,
                    precio: precio, condicion: condicion, estado: nuevo, vistas: vistas,
                    fechaPublicacion: fechaPublicacion, piezaNombre: piezaNombre,
                    piezaSku: piezaSku, vehiculoTitulo: vehiculoTitulo, fotoThumbUrl: fotoThumbUrl)
    }
}
