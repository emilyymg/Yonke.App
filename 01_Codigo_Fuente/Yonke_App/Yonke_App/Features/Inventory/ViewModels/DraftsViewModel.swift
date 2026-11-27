import Foundation
import SwiftUI
import Combine

@MainActor
final class DraftsViewModel: ObservableObject {
    @Published var drafts: [PublicationDraft] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Search query & filtering
    @Published var searchQuery = ""
    @Published var selectedStatus: DraftStatus? = nil
    
    private let service: DataServiceProtocol
    
    init(service: DataServiceProtocol = MockDataService.shared) {
        self.service = service
    }
    
    var filteredDrafts: [PublicationDraft] {
        var result = drafts
        
        if let status = selectedStatus {
            result = result.filter { $0.estado == status }
        }
        
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.nombre_pieza.lowercased().contains(q) ||
                $0.marca_vehiculo.lowercased().contains(q) ||
                $0.modelo_vehiculo.lowercased().contains(q) ||
                $0.sku_pieza.lowercased().contains(q)
            }
        }
        
        return result
    }
    
    func fetchDrafts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            drafts = try await service.fetchPublicationDrafts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func saveDraft(_ draft: PublicationDraft) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let updated = try await service.updatePublicationDraft(draft)
            if let idx = drafts.firstIndex(where: { $0.id == draft.id }) {
                drafts[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func discardDraft(id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await service.deletePublicationDraft(draftId: id)
            drafts.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func publishToMarketplace(_ draft: PublicationDraft) async {
        guard draft.estado == .listo else {
            errorMessage = "No se puede publicar un borrador que no esté listo."
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // Delete from drafts as it gets promoted to live marketplace
            try await service.deletePublicationDraft(draftId: draft.id)
            drafts.removeAll { $0.id == draft.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
