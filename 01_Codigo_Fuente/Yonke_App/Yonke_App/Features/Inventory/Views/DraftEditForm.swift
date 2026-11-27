import SwiftUI

// MARK: - DraftEditForm
/// Form for reviewing a draft: read-only part data, editable marketplace
/// fields, and the save, publish, and discard actions.

struct DraftEditForm: View {
    let draft: PublicationDraft
    let viewModel: DraftsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var titulo: String
    @State private var descripcion: String
    @State private var precioPublico: String
    @State private var condicion: String
    @State private var estado: DraftStatus
    @State private var showDiscardAlert = false

    private let condiciones = ["Excelente", "Bueno", "Regular", "Dañado"]

    init(draft: PublicationDraft, viewModel: DraftsViewModel) {
        self.draft = draft
        self.viewModel = viewModel
        _titulo = State(initialValue: draft.titulo)
        _descripcion = State(initialValue: draft.descripcion)
        _precioPublico = State(initialValue: String(format: "%.0f", draft.precio_publico_editable))
        _condicion = State(initialValue: draft.condicion_editable)
        _estado = State(initialValue: draft.estado)
    }

    var body: some View {
        Form {
            Section("Pieza (solo lectura)") {
                LabeledContent("SKU") {
                    Text(draft.sku_pieza)
                        .font(.body.monospaced())
                }
                LabeledContent("Vehículo origen", value: "\(draft.marca_vehiculo) \(draft.modelo_vehiculo) \(draft.anio_vehiculo)")
                LabeledContent("Condición real", value: draft.condicion_publicada)
                DraftPhotoStrip(photos: draft.fotos_inventario)
            }

            Section("Información para marketplace") {
                TextField("Título de venta", text: $titulo, axis: .vertical)
                    .lineLimit(1...3)

                TextField("Descripción", text: $descripcion, axis: .vertical)
                    .lineLimit(3...8)

                LabeledContent("Precio (MXN)") {
                    TextField("0", text: $precioPublico)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospaced().weight(.bold))
                        .foregroundStyle(YonkeTheme.accentGreen)
                }

                Picker("Condición de venta", selection: $condicion) {
                    ForEach(condiciones, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            }

            Section {
                Picker("Estado", selection: $estado) {
                    ForEach(DraftStatus.allCases, id: \.self) { status in
                        Text(status.label).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                if estado != .listo {
                    Text("Marca el borrador como Listo para poder publicarlo.")
                }
            }

            Section {
                Button("Guardar cambios", systemImage: "checkmark.circle.fill") {
                    Task { await saveChanges() }
                }

                Button("Publicar en marketplace", systemImage: "paperplane.fill") {
                    Task { await publish() }
                }
                .disabled(estado != .listo)
            }

            Section {
                Button("Descartar borrador", systemImage: "trash", role: .destructive) {
                    showDiscardAlert = true
                }
            }
        }
        .yonkeGroupedBackground()
        .alert("¿Descartar borrador?", isPresented: $showDiscardAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Descartar", role: .destructive) {
                Task {
                    await viewModel.discardDraft(id: draft.id)
                    dismiss()
                }
            }
        } message: {
            Text("Esta acción eliminará permanentemente este borrador de publicación.")
        }
    }

    // MARK: - Actions

    private func updatedDraft() -> PublicationDraft {
        var updated = draft
        updated.titulo = titulo
        updated.descripcion = descripcion
        updated.precio_publico_editable = Double(precioPublico) ?? draft.precio_publico_editable
        updated.condicion_editable = condicion
        updated.estado = estado
        return updated
    }

    private func saveChanges() async {
        await viewModel.saveDraft(updatedDraft())
        dismiss()
    }

    private func publish() async {
        await viewModel.publishToMarketplace(updatedDraft())
        dismiss()
    }
}
