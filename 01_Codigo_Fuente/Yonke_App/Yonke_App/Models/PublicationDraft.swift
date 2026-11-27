import Foundation

enum DraftStatus: String, Codable, CaseIterable {
    case listo = "listo"
    case pendiente = "pendiente"
    case vacio = "vacio"
    
    var label: String {
        switch self {
        case .listo: return "Listo"
        case .pendiente: return "Pendiente"
        case .vacio: return "Vacío"
        }
    }
}

struct PublicationDraft: Identifiable, Codable, Hashable {
    let id: UUID
    
    // MARK: - Read-Only/System Info (Database Fields)
    var nombre_pieza: String
    var marca_vehiculo: String
    var modelo_vehiculo: String
    var anio_vehiculo: Int
    var color_pieza: String
    var sku_pieza: String
    var precio_publico: Double
    var fotos_inventario: [String] // List of photo paths or URLs
    var condicion_publicada: String // Condición real
    
    // MARK: - Marketplace Fields (Editable)
    var titulo: String
    var descripcion: String
    var precio_publico_editable: Double
    var condicion_editable: String // Condición en marketplace
    var fotos_editables: [String] // List of edited photos
    
    // MARK: - Status
    var estado: DraftStatus
}
