import Foundation

// MARK: - Estado de pieza
/// Valores de `piezas.estado_inventario` (migración 001).

enum EstadoPieza: String, Codable, CaseIterable, Identifiable, Hashable {
    case porConfirmar = "por_confirmar"
    case disponible
    case reservado
    case vendido
    case descartado
    case enRevision = "en_revision"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .porConfirmar: return "Por confirmar"
        case .disponible:   return "Disponible"
        case .reservado:    return "Reservado"
        case .vendido:      return "Vendido"
        case .descartado:   return "Descartado"
        case .enRevision:   return "En revisión"
        }
    }

    /// Espejo de `transiciones_pieza`. La base valida lo mismo en `cambiar_estado_pieza`.
    var destinosPermitidos: [EstadoPieza] {
        switch self {
        case .porConfirmar: return [.disponible, .descartado]
        case .disponible:   return [.reservado, .vendido, .enRevision, .descartado]
        case .reservado:    return [.disponible, .vendido]
        case .enRevision:   return [.disponible, .descartado]
        case .vendido:      return [.disponible]
        case .descartado:   return []
        }
    }

    func puedeCambiarA(_ nuevo: EstadoPieza) -> Bool {
        destinosPermitidos.contains(nuevo)
    }

    /// Acciones que muestra el detalle.
    var accionesDisponibles: [AccionPieza] {
        switch self {
        case .porConfirmar: return [.confirmar, .descartar]
        case .disponible:   return [.publicar, .vender, .reservar, .descartar]
        case .reservado:    return [.vender, .liberar]
        case .vendido:      return [.verVenta, .devolver]
        case .enRevision, .descartado: return []
        }
    }
}

// MARK: - Acción sobre pieza

enum AccionPieza: Identifiable, Hashable {
    case confirmar
    case publicar
    case vender
    case reservar
    case liberar
    case verVenta
    case devolver
    case descartar

    var id: Self { self }

    var titulo: String {
        switch self {
        case .confirmar: return "Confirmar"
        case .publicar:  return "Publicar"
        case .vender:    return "Vender"
        case .reservar:  return "Reservar"
        case .liberar:   return "Liberar"
        case .verVenta:  return "Ver venta"
        case .devolver:  return "Devolver venta"
        case .descartar: return "Descartar"
        }
    }

    var icono: String {
        switch self {
        case .confirmar: return "checkmark.seal.fill"
        case .publicar:  return "megaphone.fill"
        case .vender:    return "cart.fill"
        case .reservar:  return "bookmark.fill"
        case .liberar:   return "arrow.uturn.backward"
        case .verVenta:  return "banknote.fill"
        case .devolver:  return "arrow.uturn.left.circle.fill"
        case .descartar: return "trash.fill"
        }
    }

    /// Estado destino de cambios directos. Confirmar, publicar, vender, ver venta y devolver
    /// tienen su propio flujo (hoja o confirmación), así que devuelven nil.
    var destino: EstadoPieza? {
        switch self {
        case .confirmar, .publicar, .vender, .verVenta, .devolver: return nil
        case .liberar:                                             return .disponible
        case .reservar:                                            return .reservado
        case .descartar:                                           return .descartado
        }
    }
}

// MARK: - Condición física
/// Valores del `CHECK` de `piezas.condicion`.

enum CondicionPieza: String, Codable, CaseIterable, Identifiable, Hashable {
    case nuevo
    case seminuevo
    case usado
    case refaccionado
    case danado
    case paraReparar = "para_reparar"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nuevo:        return "Nuevo"
        case .seminuevo:    return "Seminuevo"
        case .usado:        return "Usado"
        case .refaccionado: return "Refaccionado"
        case .danado:       return "Dañado"
        case .paraReparar:  return "Para reparar"
        }
    }
}

// MARK: - Foto
/// Derivados servidos desde S3 (`derivados/`). Nunca se muestran originales.

struct FotoPieza: Codable, Identifiable, Hashable {
    let id: String
    let orden: Int
    let principal: Bool
    let thumbUrl: URL?
    let mediumUrl: URL?
}

// MARK: - Pieza

struct PiezaInventario: Codable, Identifiable, Hashable {
    let id: String
    let vehiculoId: String
    let sku: String?
    let nombre: String
    let descripcion: String?
    let condicion: CondicionPieza?
    let precioVenta: Double?
    let estado: EstadoPieza
    let fotos: [FotoPieza]

    var fotoPrincipal: FotoPieza? {
        fotos.first(where: { $0.principal }) ?? fotos.min(by: { $0.orden < $1.orden })
    }

    /// Copia con fotos adicionales al final (p. ej. las recién subidas).
    func conFotos(_ adicionales: [FotoPieza]) -> PiezaInventario {
        guard !adicionales.isEmpty else { return self }
        return PiezaInventario(id: id, vehiculoId: vehiculoId, sku: sku, nombre: nombre,
                               descripcion: descripcion, condicion: condicion,
                               precioVenta: precioVenta, estado: estado,
                               fotos: fotos + adicionales)
    }

    /// Copia con los campos indicados. Útil para respuestas del servicio y tests.
    func actualizando(estado: EstadoPieza? = nil,
                      precioVenta: Double? = nil,
                      condicion: CondicionPieza? = nil) -> PiezaInventario {
        PiezaInventario(id: id, vehiculoId: vehiculoId, sku: sku, nombre: nombre,
                        descripcion: descripcion,
                        condicion: condicion ?? self.condicion,
                        precioVenta: precioVenta ?? self.precioVenta,
                        estado: estado ?? self.estado,
                        fotos: fotos)
    }
}

// MARK: - Vehículo

struct VehiculoInventario: Codable, Identifiable, Hashable {
    let id: String
    let marca: String
    let modelo: String
    let anio: Int
    let vin: String?

    var titulo: String { "\(anio) \(marca) \(modelo)" }
}

// MARK: - Catálogo de vehículos

struct MarcaVehiculo: Codable, Identifiable, Hashable {
    let id: String
    let nombre: String
}

struct ModeloVehiculo: Codable, Identifiable, Hashable {
    let id: String
    let marcaId: String
    let nombre: String
}

// MARK: - Registro de vehículo

/// Body de `POST /api/vehiculos`. El yonque sale del token, no del body.
struct RegistrarVehiculoRequest: Encodable {
    let modeloId: String
    let anio: Int

    enum CodingKeys: String, CodingKey {
        case modeloId = "modelo_id"
        case anio
    }
}

/// Respuesta de `registrar_vehiculo_con_piezas`.
struct RegistroVehiculoResultado: Decodable {
    let vehiculoId: String
    let piezasGeneradas: Int
}

// MARK: - Verificación de piezas

/// Body de `PATCH /api/piezas/:id`. Los campos nil no se envían y no cambian.
struct ActualizarPiezaRequest: Encodable {
    let nombre: String?
    let descripcion: String?
    let condicion: CondicionPieza?
    let precioVenta: Double?

    enum CodingKeys: String, CodingKey {
        case nombre
        case descripcion
        case condicion
        case precioVenta = "precio_venta"
    }
}

/// Body de `POST /api/piezas` (pieza fuera de catálogo).
struct CrearPiezaRequest: Encodable {
    let vehiculoId: String
    let nombre: String
    let descripcion: String?
    let condicion: CondicionPieza?
    let precioVenta: Double?

    enum CodingKeys: String, CodingKey {
        case vehiculoId = "vehiculo_id"
        case nombre
        case descripcion
        case condicion
        case precioVenta = "precio_venta"
    }
}

/// Body de `POST /api/vehiculos/:id/verificacion/confirmar`.
struct ConfirmarVerificacionRequest: Encodable {
    let piezasIds: [String]

    enum CodingKeys: String, CodingKey {
        case piezasIds = "piezas_ids"
    }
}

/// Respuesta de la confirmación en lote.
struct ResultadoVerificacion: Decodable, Equatable {
    /// Piezas que pasaron a disponible.
    let confirmadas: Int
    /// Ids de piezas que siguen por confirmar (sin precio o condición).
    let pendientes: [String]
}

/// Respuesta de `POST /api/piezas/:id/descartar`.
struct RespuestaDescarte: Decodable {
    /// "eliminada" si se borró la pieza; "descartada" si tenía historial.
    let resultado: String
}
