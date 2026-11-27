import Foundation

/// Rutas relativas a `AppConfig.apiBaseURL`. Espejo de `Yonke_Back/mi-backend/server.js`.
enum APIPath {
    // Sesión y perfil
    static let login = "/users/login"
    static let yonqueMio = "/yonques/mio"
    static let fotosUploadURL = "/fotos/upload-url"
    static func foto(_ id: String) -> String { "/fotos/\(id)" }

    // Inventario
    static let vehiculos = "/vehiculos"
    static func vehiculo(_ id: String) -> String { "/vehiculos/\(id)" }
    static let piezas = "/piezas"
    static func pieza(_ id: String) -> String { "/piezas/\(id)" }
    static func confirmarPieza(_ id: String) -> String { "/piezas/\(id)/confirmar" }
    static func estadoPieza(_ id: String) -> String { "/piezas/\(id)/estado" }
    static func descartarPieza(_ id: String) -> String { "/piezas/\(id)/descartar" }
    static func verificacionVehiculo(_ id: String) -> String { "/vehiculos/\(id)/verificacion/confirmar" }
    static let marcas = "/catalogos/marcas"
    static func modelos(marcaId: String) -> String { "/catalogos/marcas/\(marcaId)/modelos" }

    // Ventas
    static let ventas = "/ventas"
    static func devolverVenta(_ id: String) -> String { "/ventas/\(id)/devolver" }

    // Borradores y publicaciones
    static let borradores = "/borradores"
    static func borrador(_ id: String) -> String { "/borradores/\(id)" }
    static func publicarBorrador(_ id: String) -> String { "/borradores/\(id)/publicar" }
    static func reabrirBorrador(_ id: String) -> String { "/borradores/\(id)/reabrir" }
    static let publicacionesMias = "/publicaciones/mias"
    static func estadoPublicacion(_ id: String) -> String { "/publicaciones/\(id)/estado" }
}
