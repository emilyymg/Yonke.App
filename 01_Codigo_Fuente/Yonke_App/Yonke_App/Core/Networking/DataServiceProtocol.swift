import Foundation

// MARK: - Batch Conversion Input
/// Represents a single item in the dismantling checklist before it becomes a Part.
struct PartDraft {
    var name: String
    var category: String
    var condition: PartCondition
    var price: Double
    var description: String?
}

// MARK: - Data Service Protocol
/// Defines all data operations. Conform MockDataService for development,
/// and a future RealDataService for production (PostgreSQL + S3).
protocol DataServiceProtocol {
    // Vehicles
    func fetchVehicles() async throws -> [Vehicle]
    func uploadVehicle(_ vehicle: Vehicle) async throws -> Vehicle
    func updateVehicleStatus(vehicleId: UUID, status: VehicleStatus) async throws -> Vehicle
    func deleteVehicle(vehicleId: UUID) async throws

    // Parts
    func fetchAllParts() async throws -> [Part]
    func fetchParts(forVehicleId vehicleId: UUID) async throws -> [Part]
    func createPartsBatch(_ parts: [Part]) async throws -> [Part]

    // Images
    func uploadImage(data: Data, path: String) async throws -> String

    // Publication Drafts
    func fetchPublicationDrafts() async throws -> [PublicationDraft]
    func updatePublicationDraft(_ draft: PublicationDraft) async throws -> PublicationDraft
    func deletePublicationDraft(draftId: UUID) async throws
}

