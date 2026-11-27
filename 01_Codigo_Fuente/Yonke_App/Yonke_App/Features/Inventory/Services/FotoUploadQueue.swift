import Foundation
import Combine

// MARK: - SubidaPendiente

struct SubidaPendiente: Codable, Identifiable, Equatable {
    enum Estado: String, Codable {
        case pendiente
        case subiendo
        case fallido
    }

    let id: UUID
    let piezaId: String
    /// Nombre del JPEG dentro de la carpeta de la cola.
    let archivo: String
    var estado: Estado
    var intentos: Int
    var ultimoError: String?
    var proximoIntento: Date
}

// MARK: - FotoUploadQueue
/// Cola persistente de subidas de fotos. Cada foto se guarda en disco antes de subirla,
/// así sobrevive a cierres de la app y a la falta de red. Reintenta con backoff
/// exponencial y deja de reintentar automáticamente tras `maxIntentos`.

@MainActor
final class FotoUploadQueue: ObservableObject {

    static let shared = FotoUploadQueue()

    static let maxIntentos = 5

    @Published private(set) var subidas: [SubidaPendiente] = []
    /// Aumenta con cada foto subida. Las vistas lo observan para releer la pieza.
    @Published private(set) var exitosas = 0

    private let service: FotoServiceProtocol
    private let directorio: URL
    private let archivoIndice: URL
    private var procesando = false
    private var temporizador: Task<Void, Never>?

    init(service: FotoServiceProtocol = RemoteFotoService.shared, directorio: URL? = nil) {
        self.service = service

        let base = directorio ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SubidasFotos", isDirectory: true)
        self.directorio = base
        self.archivoIndice = base.appendingPathComponent("cola.json")

        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        // Lo que estaba "subiendo" al cerrar la app vuelve a la cola.
        subidas = Self.cargarIndice(desde: archivoIndice).map { subida in
            var restaurada = subida
            if restaurada.estado == .subiendo { restaurada.estado = .pendiente }
            return restaurada
        }
        if subidas.contains(where: { $0.estado == .pendiente }) {
            Task { await procesar() }
        }
    }

    // MARK: - API pública

    /// Guarda la foto en disco y la encola. `datos` debe ser JPEG ya comprimido.
    func agregar(datos: Data, piezaId: String) {
        let id = UUID()
        let nombre = "\(id.uuidString).jpg"

        do {
            try datos.write(to: directorio.appendingPathComponent(nombre), options: .atomic)
        } catch {
            return
        }

        subidas.append(SubidaPendiente(id: id, piezaId: piezaId, archivo: nombre,
                                       estado: .pendiente, intentos: 0,
                                       ultimoError: nil, proximoIntento: Date()))
        guardar()
        Task { await procesar() }
    }

    /// Reinicia los intentos de una subida fallida.
    func reintentar(_ id: UUID) {
        actualizar(id) {
            $0.estado = .pendiente
            $0.intentos = 0
            $0.ultimoError = nil
            $0.proximoIntento = Date()
        }
        guardar()
        Task { await procesar() }
    }

    /// Ruta del JPEG local de una subida, para mostrar su miniatura antes de subirla.
    func archivoURL(de subida: SubidaPendiente) -> URL {
        directorio.appendingPathComponent(subida.archivo)
    }

    /// Quita una subida de la cola y borra su archivo.
    func descartar(_ id: UUID) {
        guard let subida = subidas.first(where: { $0.id == id }) else { return }
        eliminar(subida)
        guardar()
    }

    /// Procesa en orden las subidas listas. Llamar también al volver a primer plano.
    func procesar() async {
        guard !procesando else { return }
        procesando = true
        defer { procesando = false }

        while let siguiente = subidas.first(where: { $0.estado == .pendiente && $0.proximoIntento <= Date() }) {
            await subir(siguiente)
        }
        programarSiguiente()
    }

    // MARK: - Subida

    private func subir(_ subida: SubidaPendiente) async {
        actualizar(subida.id) { $0.estado = .subiendo }

        do {
            let datos = try Data(contentsOf: directorio.appendingPathComponent(subida.archivo))
            let destino = try await service.solicitarUploadURL(piezaId: subida.piezaId,
                                                               clienteId: subida.id.uuidString)
            try await service.subir(datos, hacia: destino.uploadUrl)
            eliminar(subida)
            exitosas += 1
        } catch {
            registrarFallo(subida.id, error: error)
        }
        guardar()
    }

    private func registrarFallo(_ id: UUID, error: Error) {
        let mensaje = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        actualizar(id) { subida in
            subida.intentos += 1
            subida.ultimoError = mensaje
            if subida.intentos >= Self.maxIntentos {
                subida.estado = .fallido
            } else {
                subida.estado = .pendiente
                subida.proximoIntento = Date().addingTimeInterval(Self.espera(paraIntento: subida.intentos))
            }
        }
    }

    /// Espera antes del siguiente intento: 10 s, 20 s, 40 s, 80 s, con tope de 5 min.
    static func espera(paraIntento intento: Int) -> TimeInterval {
        min(300, 5 * pow(2, Double(intento)))
    }

    // MARK: - Helpers

    private func actualizar(_ id: UUID, _ cambio: (inout SubidaPendiente) -> Void) {
        guard let posicion = subidas.firstIndex(where: { $0.id == id }) else { return }
        cambio(&subidas[posicion])
    }

    private func eliminar(_ subida: SubidaPendiente) {
        try? FileManager.default.removeItem(at: directorio.appendingPathComponent(subida.archivo))
        subidas.removeAll { $0.id == subida.id }
    }

    /// Despierta la cola cuando vence el intento más cercano.
    private func programarSiguiente() {
        temporizador?.cancel()
        temporizador = nil

        guard let proxima = subidas
            .filter({ $0.estado == .pendiente })
            .map(\.proximoIntento)
            .min() else { return }

        let espera = max(0, proxima.timeIntervalSinceNow)
        temporizador = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(espera * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.procesar()
        }
    }

    private func guardar() {
        guard let datos = try? JSONEncoder().encode(subidas) else { return }
        try? datos.write(to: archivoIndice, options: .atomic)
    }

    private static func cargarIndice(desde url: URL) -> [SubidaPendiente] {
        guard let datos = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([SubidaPendiente].self, from: datos)) ?? []
    }
}
