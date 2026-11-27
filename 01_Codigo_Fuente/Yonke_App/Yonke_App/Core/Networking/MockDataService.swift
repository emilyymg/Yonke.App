import Foundation

// MARK: - Mock Data Service

/// Development implementation of DataServiceProtocol.
/// Returns seeded in-memory data with simulated network delays.
/// Replace with RealDataService when the backend is ready.
final class MockDataService: DataServiceProtocol {

    nonisolated static let shared = MockDataService()

    // MARK: - In-Memory Store
    private var mockVehicles: [Vehicle] = []
    private var mockParts: [Part] = []
    private var mockDrafts: [PublicationDraft] = []

    private init() { seedData() }

    // MARK: - Seed
    private func seedData() {
        let v1id = UUID()
        let v2id = UUID()
        let v3id = UUID()
        
        mockDrafts = [
            PublicationDraft(
                id: UUID(),
                nombre_pieza: "Motor Completo 2.0L",
                marca_vehiculo: "Toyota",
                modelo_vehiculo: "Corolla",
                anio_vehiculo: 2015,
                color_pieza: "Plata",
                sku_pieza: "SKU-TOY-COR-15-001",
                precio_publico: 1500.0,
                fotos_inventario: ["https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=300&auto=format&fit=crop"],
                condicion_publicada: "Excelente",
                titulo: "Motor Toyota Corolla 2015 2.0L Garantizado",
                descripcion: "Motor completo con 80,000 kilómetros. Excelente compresión, probado y listo para montar.",
                precio_publico_editable: 1500.0,
                condicion_editable: "Excelente",
                fotos_editables: ["https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=300&auto=format&fit=crop"],
                estado: .listo
            ),
            PublicationDraft(
                id: UUID(),
                nombre_pieza: "Alternador de Corriente",
                marca_vehiculo: "Honda",
                modelo_vehiculo: "Civic",
                anio_vehiculo: 2018,
                color_pieza: "Metálico",
                sku_pieza: "SKU-HON-CIV-18-005",
                precio_publico: 120.0,
                fotos_inventario: ["https://images.unsplash.com/photo-1517524206127-48bbd363f3d7?q=80&w=300&auto=format&fit=crop"],
                condicion_publicada: "Bueno",
                titulo: "Alternador Honda Civic 2018",
                descripcion: "", // Vacío para representar Pendiente
                precio_publico_editable: 120.0,
                condicion_editable: "Bueno",
                fotos_editables: [],
                estado: .pendiente
            ),
            PublicationDraft(
                id: UUID(),
                nombre_pieza: "Puerta Delantera Derecha",
                marca_vehiculo: "Ford",
                modelo_vehiculo: "F-150",
                anio_vehiculo: 2012,
                color_pieza: "Negro",
                sku_pieza: "SKU-FOR-F15-12-009",
                precio_publico: 250.0,
                fotos_inventario: [], // Vacío para representar Vacío
                condicion_publicada: "Dañado",
                titulo: "", // Vacío
                descripcion: "", // Vacío
                precio_publico_editable: 0.0,
                condicion_editable: "Bueno",
                fotos_editables: [],
                estado: .vacio
            )
        ]

        mockVehicles = [
            Vehicle(id: v1id,  make: "Toyota",  model: "Corolla", year: 2015, vin: "1NXBR12E35Z123456", status: .received,    purchaseDate: daysAgo(5),  createdAt: daysAgo(5),  updatedAt: daysAgo(5)),
            Vehicle(id: v2id,  make: "Honda",   model: "Civic",   year: 2018, vin: "2HGES165X8H512345", status: .processing,  purchaseDate: daysAgo(12), createdAt: daysAgo(12), updatedAt: daysAgo(2)),
            Vehicle(id: v3id,  make: "Ford",    model: "F-150",   year: 2012, vin: "1FTRF12345NB00001", status: .dismantled,  purchaseDate: daysAgo(30), createdAt: daysAgo(30), updatedAt: daysAgo(1)),
        ]

        mockParts = [
            Part(id: UUID(), vehicleId: v1id, name: "Alternador",                description: "Funcionando, probado",       category: "Motor",       condition: .good,      price: 120.0, isSold: false, createdAt: daysAgo(4),  updatedAt: daysAgo(4)),
            Part(id: UUID(), vehicleId: v2id, name: "Puerta Delantera Derecha",  description: "Color negro, sin rayones",    category: "Carrocería",  condition: .excellent, price: 250.0, isSold: false, createdAt: daysAgo(11), updatedAt: daysAgo(11)),
            Part(id: UUID(), vehicleId: v2id, name: "Faro Delantero Izquierdo",  description: "Sin fisuras",                 category: "Eléctrico",   condition: .good,      price: 80.0,  isSold: false, createdAt: daysAgo(11), updatedAt: daysAgo(11)),
            Part(id: UUID(), vehicleId: v3id, name: "Transmisión Automática",    description: "Requiere servicio de banda",  category: "Transmisión", condition: .fair,      price: 400.0, isSold: false, createdAt: daysAgo(29), updatedAt: daysAgo(1)),
            Part(id: UUID(), vehicleId: v3id, name: "Diferencial Trasero",       description: "Buen estado general",         category: "Transmisión", condition: .good,      price: 310.0, isSold: false, createdAt: daysAgo(29), updatedAt: daysAgo(1)),
            Part(id: UUID(), vehicleId: v3id, name: "Motor 5.0 V8",              description: "150k km, compresión ok",      category: "Motor",       condition: .fair,      price: 1800.0, isSold: true, createdAt: daysAgo(28), updatedAt: daysAgo(5)),
        ]
    }

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
    }

    // MARK: - Vehicles
    func fetchVehicles() async throws -> [Vehicle] {
        try await delay(0.6)
        return mockVehicles
    }

    func uploadVehicle(_ vehicle: Vehicle) async throws -> Vehicle {
        try await delay(0.8)
        mockVehicles.append(vehicle)
        return vehicle
    }

    func updateVehicleStatus(vehicleId: UUID, status: VehicleStatus) async throws -> Vehicle {
        try await delay(0.5)
        guard let idx = mockVehicles.firstIndex(where: { $0.id == vehicleId }) else {
            throw MockError.notFound
        }
        let old = mockVehicles[idx]
        let updated = Vehicle(id: old.id, make: old.make, model: old.model, year: old.year,
                              vin: old.vin, status: status, purchaseDate: old.purchaseDate,
                              createdAt: old.createdAt, updatedAt: Date())
        mockVehicles[idx] = updated
        return updated
    }

    func deleteVehicle(vehicleId: UUID) async throws {
        try await delay(0.4)
        mockVehicles.removeAll { $0.id == vehicleId }
        mockParts.removeAll { $0.vehicleId == vehicleId }
    }

    // MARK: - Parts
    func fetchAllParts() async throws -> [Part] {
        try await delay(0.6)
        return mockParts
    }

    func fetchParts(forVehicleId vehicleId: UUID) async throws -> [Part] {
        try await delay(0.5)
        return mockParts.filter { $0.vehicleId == vehicleId }
    }

    func createPartsBatch(_ parts: [Part]) async throws -> [Part] {
        try await delay(1.0)
        mockParts.append(contentsOf: parts)
        return parts
    }

    // MARK: - Images
    func uploadImage(data: Data, path: String) async throws -> String {
        try await delay(0.8)
        return "https://mock-storage.yonkeapp.local/\(path)/\(UUID().uuidString).jpg"
    }

    // MARK: - Publication Drafts
    func fetchPublicationDrafts() async throws -> [PublicationDraft] {
        try await delay(0.5)
        return mockDrafts
    }

    func updatePublicationDraft(_ draft: PublicationDraft) async throws -> PublicationDraft {
        try await delay(0.5)
        if let idx = mockDrafts.firstIndex(where: { $0.id == draft.id }) {
            mockDrafts[idx] = draft
            return draft
        } else {
            mockDrafts.append(draft)
            return draft
        }
    }

    func deletePublicationDraft(draftId: UUID) async throws {
        try await delay(0.4)
        mockDrafts.removeAll { $0.id == draftId }
    }

    // MARK: - Helpers
    private func delay(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Mock Errors
enum MockError: LocalizedError {
    case notFound
    var errorDescription: String? {
        switch self {
        case .notFound: return "El registro no fue encontrado en el almacenamiento local."
        }
    }
}
