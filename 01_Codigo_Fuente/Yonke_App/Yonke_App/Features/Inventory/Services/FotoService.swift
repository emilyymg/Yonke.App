import Foundation

// MARK: - Protocolo
/// Subida de fotos en dos pasos:
/// 1. `solicitarUploadURL` → el backend crea la fila en `fotos` y devuelve una URL prefirmada PUT.
/// 2. `subir` → PUT directo a S3. La app no envía bytes por el backend.
/// Los derivados `thumb`/`medium` los genera una Lambda; la app vuelve a leer la pieza para verlos.

struct UploadURLRespuesta: Decodable {
    let fotoId: String
    let uploadUrl: URL
}

protocol FotoServiceProtocol {
    /// `clienteId` es el id local de la subida. Permite al backend no duplicar fotos en reintentos.
    func solicitarUploadURL(piezaId: String, clienteId: String) async throws -> UploadURLRespuesta
    func subir(_ datos: Data, hacia url: URL) async throws
    /// Quita la foto de la pieza. El objeto en S3 queda, como en el backend.
    func eliminarFoto(id: String) async throws
}

enum FotoError: LocalizedError {
    case subidaRechazada(status: Int)
    case archivoInvalido

    var errorDescription: String? {
        switch self {
        case .subidaRechazada(let status):
            return "S3 rechazó la foto (código \(status))."
        case .archivoInvalido:
            return "No se pudo leer la foto."
        }
    }
}

// MARK: - Implementación remota
/// Usa `/api/fotos/upload-url` y PUT a la URL prefirmada. El PUT no lleva Authorization:
/// S3 rechaza encabezados que no formaron parte de la firma.

final class RemoteFotoService: FotoServiceProtocol {

    nonisolated static let shared = RemoteFotoService()

    private let api: APIClient
    private let session: URLSession

    private init(api: APIClient = .shared, session: URLSession = .shared) {
        self.api = api
        self.session = session
    }

    func solicitarUploadURL(piezaId: String, clienteId: String) async throws -> UploadURLRespuesta {
        try await api.request(.post, APIPath.fotosUploadURL,
                              body: SolicitudUploadURL(piezaId: piezaId, clienteId: clienteId))
    }

    func subir(_ datos: Data, hacia url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.upload(for: request, from: datos)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw FotoError.subidaRechazada(status: http.statusCode)
        }
    }

    func eliminarFoto(id: String) async throws {
        let _: MensajeFoto = try await api.request(.delete, APIPath.foto(id))
    }

    private struct SolicitudUploadURL: Encodable {
        let piezaId: String
        let clienteId: String

        enum CodingKeys: String, CodingKey {
            case piezaId = "pieza_id"
            case clienteId = "cliente_id"
        }
    }

    private struct MensajeFoto: Decodable {
        let message: String
    }
}

// MARK: - Mock
/// Simula S3 y la Lambda de derivados. El `fotoId` viaja en la ruta de la URL
/// (`originales/{piezaId}/{fotoId}.jpg`) para que el mock sepa a qué pieza pertenece.

final class MockFotoService: FotoServiceProtocol {

    nonisolated static let shared = MockFotoService()

    /// Probabilidad de fallo simulado en el PUT (0...1). Útil para probar los reintentos.
    var probabilidadFalloSubida: Double = 0

    private init() {}

    func solicitarUploadURL(piezaId: String, clienteId: String) async throws -> UploadURLRespuesta {
        try await delay(0.3)
        let fotoId = UUID().uuidString
        guard let url = URL(string: "https://mock-s3.yonke.local/originales/\(piezaId)/\(fotoId).jpg") else {
            throw FotoError.archivoInvalido
        }
        return UploadURLRespuesta(fotoId: fotoId, uploadUrl: url)
    }

    func subir(_ datos: Data, hacia url: URL) async throws {
        try await delay(1.0)
        guard datos.count > 0 else { throw FotoError.archivoInvalido }

        if Double.random(in: 0..<1) < probabilidadFalloSubida {
            throw URLError(.networkConnectionLost)
        }

        let fotoId = url.deletingPathExtension().lastPathComponent
        let piezaId = url.deletingLastPathComponent().lastPathComponent
        MockFotoStore.shared.agregar(piezaId: piezaId, fotoId: fotoId)
    }

    func eliminarFoto(id: String) async throws {
        try await delay(0.3)
        MockFotoStore.shared.eliminar(fotoId: id)
    }

    private func delay(_ segundos: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(segundos * 1_000_000_000))
    }
}

// MARK: - Almacén mock de fotos
/// Fotos "generadas" por el mock. El servicio de inventario las mezcla al leer piezas.

final class MockFotoStore {

    nonisolated static let shared = MockFotoStore()

    private var fotosPorPieza: [String: [FotoPieza]] = [:]
    private let fuentes = [
        "photo-1486006920555-c77dce18193b",
        "photo-1517524206127-48bbd363f3d7"
    ]

    private init() {}

    func fotos(piezaId: String) -> [FotoPieza] {
        fotosPorPieza[piezaId] ?? []
    }

    /// Quita la foto de la pieza que la tenga y renumera orden y principal.
    func eliminar(fotoId: String) {
        for (piezaId, fotos) in fotosPorPieza where fotos.contains(where: { $0.id == fotoId }) {
            let restantes = fotos.filter { $0.id != fotoId }
            let principalPerdida = fotos.first { $0.id == fotoId }?.principal == true
            fotosPorPieza[piezaId] = restantes.enumerated().map { indice, foto in
                FotoPieza(id: foto.id, orden: indice,
                          principal: principalPerdida ? indice == 0 : foto.principal,
                          thumbUrl: foto.thumbUrl, mediumUrl: foto.mediumUrl)
            }
        }
    }

    func agregar(piezaId: String, fotoId: String) {
        let existentes = fotosPorPieza[piezaId] ?? []
        let fuente = fuentes[existentes.count % fuentes.count]
        let nueva = FotoPieza(
            id: fotoId,
            orden: existentes.count,
            principal: existentes.isEmpty,
            thumbUrl: Self.url(fuente, ancho: 320),
            mediumUrl: Self.url(fuente, ancho: 1024)
        )
        fotosPorPieza[piezaId] = existentes + [nueva]
    }

    private static func url(_ photoID: String, ancho: Int) -> URL? {
        URL(string: "https://images.unsplash.com/\(photoID)?q=80&auto=format&fit=crop&w=\(ancho)")
    }
}
