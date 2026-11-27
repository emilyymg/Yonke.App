import Foundation

// MARK: - Método de pago
/// Valores del `CHECK` de `ventas.metodo_pago`.

enum MetodoPago: String, Codable, CaseIterable, Identifiable, Hashable {
    case efectivo
    case tarjeta
    case transferencia
    case deposito
    case credito
    case otro

    var id: String { rawValue }

    var label: String {
        switch self {
        case .efectivo:      return "Efectivo"
        case .tarjeta:       return "Tarjeta"
        case .transferencia: return "Transferencia"
        case .deposito:      return "Depósito"
        case .credito:       return "Crédito"
        case .otro:          return "Otro"
        }
    }
}

// MARK: - Estado de venta
/// Valores de `ventas.estado`.

enum EstadoVenta: String, Codable, CaseIterable, Identifiable, Hashable {
    case pendiente
    case completada
    case cancelada
    case devuelta
    case garantia

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pendiente:  return "Pendiente"
        case .completada: return "Completada"
        case .cancelada:  return "Cancelada"
        case .devuelta:   return "Devuelta"
        case .garantia:   return "En garantía"
        }
    }

    /// Una venta vigente ocupa la pieza. Solo puede haber una por pieza.
    var estaVigente: Bool {
        self == .pendiente || self == .completada || self == .garantia
    }
}

// MARK: - Venta

struct Venta: Codable, Identifiable, Hashable {
    let id: String
    let piezaId: String
    let compradorNombre: String?
    let precioFinal: Double
    let metodoPago: MetodoPago
    let estado: EstadoVenta
    let notas: String?
    let fechaVenta: Date

    let piezaNombre: String
    let piezaSku: String?
    let vehiculoTitulo: String?
    let fotoThumbUrl: URL?

    func conEstado(_ nuevo: EstadoVenta) -> Venta {
        Venta(id: id, piezaId: piezaId, compradorNombre: compradorNombre, precioFinal: precioFinal,
              metodoPago: metodoPago, estado: nuevo, notas: notas, fechaVenta: fechaVenta,
              piezaNombre: piezaNombre, piezaSku: piezaSku, vehiculoTitulo: vehiculoTitulo,
              fotoThumbUrl: fotoThumbUrl)
    }
}

/// Datos capturados para `procesar_venta`.
struct VentaInput: Equatable {
    var compradorNombre: String
    var precioFinal: Double
    var metodoPago: MetodoPago
    var notas: String
}
