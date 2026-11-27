import Foundation

/// Datos del yonque del usuario autenticado (`GET /api/yonques/mio`).
struct Yonque: Decodable, Identifiable, Equatable {
    let id: String
    let nombre: String
    let telefono: String?
    let ubicacion: Ubicacion?
    let resumen: Resumen?

    struct Resumen: Decodable, Equatable {
        let piezasPorConfirmar: Int
        let piezasDisponibles: Int
        let totalVehiculos: Int
        let publicacionesActivas: Int
    }

    struct Ubicacion: Decodable, Equatable {
        let direccion: String?
        let ciudad: String?
        let estado: String?
        let codigoPostal: String?

        /// Dirección en una sola línea, omitiendo los campos vacíos.
        var linea: String {
            [direccion, ciudad, estado, codigoPostal]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
    }
}
