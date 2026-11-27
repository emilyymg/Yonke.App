import Foundation

/// Configuración del backend de desarrollo (`Yonke_Back/mi-backend`, Express, PORT=3001).
/// Puerto 3000 es el servidor Next.js de la web (YonkeMain), no la API.
enum AppConfig {
    #if targetEnvironment(simulator)
    static let serverBaseURL = "http://localhost:3001"
    #else
    /// iPhone físico: IP LAN del Mac que corre el backend (`ipconfig getifaddr en0`).
    static let serverBaseURL = "http://192.168.1.77:3001"
    #endif

    static var apiBaseURL: String { serverBaseURL + "/api" }
}
