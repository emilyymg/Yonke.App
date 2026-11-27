import SwiftUI

// MARK: - DraftDetailSheet
/// Sheet wrapper that looks up the selected draft and shows its edit form.

struct DraftDetailSheet: View {
    @ObservedObject var viewModel: DraftsViewModel
    let draftId: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let draft = viewModel.drafts.first(where: { $0.id == draftId }) {
                    DraftEditForm(draft: draft, viewModel: viewModel)
                } else {
                    ContentUnavailableView("Borrador no disponible", systemImage: "doc.questionmark")
                }
            }
            .navigationTitle("Detalle de borrador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
