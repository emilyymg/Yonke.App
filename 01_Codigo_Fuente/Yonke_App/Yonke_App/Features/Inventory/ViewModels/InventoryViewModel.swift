import Foundation
import SwiftUI
import Combine


// MARK: - Inventory Filter / Sort Options

enum InventoryFilter: String, CaseIterable, Identifiable {
    case all         = "Todos"
    case available   = "Disponibles"
    case sold        = "Vendidos"
    var id: String { rawValue }
}

enum InventorySortOrder: String, CaseIterable, Identifiable {
    case newest      = "Más recientes"
    case priceAsc    = "Precio ↑"
    case priceDesc   = "Precio ↓"
    case name        = "Nombre A-Z"
    var id: String { rawValue }
}

// MARK: - InventoryViewModel

/// Manages the full inventory: search, filter, sort, and stats.
/// Receives parts from a DataServiceProtocol so the backend can be swapped
/// from MockDataService → RealDataService without touching this class.
@MainActor
final class InventoryViewModel: ObservableObject {

    // MARK: - Published State
    @Published var allParts: [Part] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Filter / Search / Sort Controls
    @Published var searchQuery: String = "" {
        didSet { applyFiltersAndSort() }
    }
    @Published var activeFilter: InventoryFilter = .all {
        didSet { applyFiltersAndSort() }
    }
    @Published var activeSortOrder: InventorySortOrder = .newest {
        didSet { applyFiltersAndSort() }
    }
    @Published var selectedCategory: String? = nil {
        didSet { applyFiltersAndSort() }
    }

    // MARK: - Derived / Computed State
    @Published private(set) var displayedParts: [Part] = []

    /// All distinct categories found in the current inventory.
    var availableCategories: [String] {
        Array(Set(allParts.map { $0.category })).sorted()
    }

    // MARK: - Stats (great for the Dashboard header)
    var totalParts: Int       { allParts.count }
    var availableCount: Int   { allParts.filter { !$0.isSold }.count }
    var soldCount: Int        { allParts.filter { $0.isSold }.count }
    var totalValue: Double    { allParts.filter { !$0.isSold }.reduce(0) { $0 + $1.price } }

    // MARK: - Dependency
    private let service: DataServiceProtocol

    init(service: DataServiceProtocol = MockDataService.shared) {
        self.service = service
    }

    // MARK: - Data Loading

    func fetchInventory() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            allParts = try await service.fetchAllParts()
            applyFiltersAndSort()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load only the parts that belong to a specific vehicle.
    func fetchInventory(forVehicleId vehicleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            allParts = try await service.fetchParts(forVehicleId: vehicleId)
            applyFiltersAndSort()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Filtering & Sorting Engine

    private func applyFiltersAndSort() {
        var result = allParts

        // 1. Filter by sale status
        switch activeFilter {
        case .all:       break
        case .available: result = result.filter { !$0.isSold }
        case .sold:      result = result.filter {  $0.isSold }
        }

        // 2. Filter by category
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }

        // 3. Search by name or description
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                ($0.description?.lowercased().contains(q) == true) ||
                $0.category.lowercased().contains(q)
            }
        }

        // 4. Sort
        switch activeSortOrder {
        case .newest:    result.sort { $0.createdAt > $1.createdAt }
        case .priceAsc:  result.sort { $0.price < $1.price }
        case .priceDesc: result.sort { $0.price > $1.price }
        case .name:      result.sort { $0.name < $1.name }
        }

        displayedParts = result
    }

    // MARK: - Part Updates

    /// Locally marks a part as sold (call after a real payment flow).
    func markAsSold(part: Part) async {
        // When backend exists: PATCH /parts/{id} { isSold: true }
        // For now, update in-memory and reflect in UI.
        if let idx = allParts.firstIndex(where: { $0.id == part.id }) {
            let updated = Part(
                id: part.id, vehicleId: part.vehicleId,
                name: part.name, description: part.description,
                category: part.category, condition: part.condition,
                price: part.price, isSold: true,
                createdAt: part.createdAt, updatedAt: Date()
            )
            allParts[idx] = updated
            applyFiltersAndSort()
        }
    }

    // MARK: - Convenience Batch Insert (called from VehicleViewModel result)

    /// Merges newly-created parts from a batch conversion into the current inventory view.
    func appendBatch(_ parts: [Part]) {
        allParts.append(contentsOf: parts)
        applyFiltersAndSort()
    }

    // MARK: - Image Upload Helper

    func uploadImage(data: Data, forPart part: Part) async -> String? {
        let path = "parts/\(part.vehicleId.uuidString)"
        do {
            return try await service.uploadImage(data: data, path: path)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
