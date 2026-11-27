import SwiftUI

// MARK: - InventoryBoardView
/// Publication drafts tab: searchable grid of part thumbnails, a status
/// filter, and a sheet for reviewing and editing marketplace details.

struct InventoryBoardView: View {
    @StateObject private var viewModel = DraftsViewModel()
    @State private var selectedDraft: PublicationDraft?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statsStrip
                    statusFilter
                    content
                }
                .padding()
            }
            .yonkeGroupedBackground()
            .navigationTitle("Borradores")
            .navigationSubtitle("Optimiza las piezas antes de publicarlas")
            .searchable(text: $viewModel.searchQuery, prompt: "Pieza, SKU, marca…")
            .task {
                await viewModel.fetchDrafts()
            }
            .refreshable {
                await viewModel.fetchDrafts()
            }
            .sheet(item: $selectedDraft) { draft in
                DraftDetailSheet(viewModel: viewModel, draftId: draft.id)
            }
        }
    }

    // MARK: - Filter and stats

    private var statusFilter: some View {
        Picker("Estado", selection: $viewModel.selectedStatus) {
            Text("Todos").tag(DraftStatus?.none)
            ForEach(DraftStatus.allCases, id: \.self) { status in
                Text(status.label).tag(Optional(status))
            }
        }
        .pickerStyle(.segmented)
    }

    private var statsStrip: some View {
        HStack(spacing: 12) {
            DraftStatBadge(label: "Listos", count: count(of: .listo), color: YonkeTheme.draftStatusColor(.listo))
            DraftStatBadge(label: "Pendientes", count: count(of: .pendiente), color: YonkeTheme.draftStatusColor(.pendiente))
            DraftStatBadge(label: "Vacíos", count: count(of: .vacio), color: YonkeTheme.draftStatusColor(.vacio))
        }
    }

    private func count(of status: DraftStatus) -> Int {
        viewModel.drafts.filter { $0.estado == status }.count
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.drafts.isEmpty {
            ProgressView("Sincronizando borradores…")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if viewModel.filteredDrafts.isEmpty {
            if viewModel.searchQuery.isEmpty {
                ContentUnavailableView(
                    "Sin borradores",
                    systemImage: "square.dashed",
                    description: Text("No hay piezas en este estado de publicación actualmente.")
                )
            } else {
                ContentUnavailableView.search
            }
        } else {
            draftsGrid
        }
    }

    private var draftsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.filteredDrafts) { draft in
                Button {
                    selectedDraft = draft
                } label: {
                    DraftThumbnailCard(draft: draft)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
