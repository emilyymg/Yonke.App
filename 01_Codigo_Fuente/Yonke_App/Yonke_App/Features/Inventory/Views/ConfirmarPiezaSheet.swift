import SwiftUI

// MARK: - ConfirmarPiezaSheet
/// Captura precio y condición para dejar una pieza por confirmar como disponible.
/// Las fotos se agregan en la misma hoja; sus subidas siguen en cola aunque se cierre.

struct ConfirmarPiezaSheet: View {
    let onFotosCambiadas: () -> Void
    let onConfirmada: (PiezaInventario) -> Void

    @StateObject private var viewModel: ConfirmarPiezaViewModel
    @ObservedObject private var cola = FotoUploadQueue.shared
    @Environment(\.dismiss) private var dismiss

    init(pieza: PiezaInventario,
         onFotosCambiadas: @escaping () -> Void = {},
         onConfirmada: @escaping (PiezaInventario) -> Void) {
        self.onFotosCambiadas = onFotosCambiadas
        self.onConfirmada = onConfirmada
        _viewModel = StateObject(wrappedValue: ConfirmarPiezaViewModel(pieza: pieza))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pieza") {
                    LabeledContent("Nombre", value: viewModel.pieza.nombre)
                    if let sku = viewModel.pieza.sku {
                        LabeledContent("SKU", value: sku)
                    }
                }

                Section("Precio de venta") {
                    LabeledContent("Precio (MXN)") {
                        TextField("0.00", text: $viewModel.precioTexto)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Condición") {
                    Picker("Condición", selection: $viewModel.condicion) {
                        Text("Selecciona").tag(CondicionPieza?.none)
                        ForEach(CondicionPieza.allCases) { condicion in
                            Text(condicion.label).tag(CondicionPieza?.some(condicion))
                        }
                    }
                }

                Section("Fotos") {
                    FotosPiezaControles(piezaId: viewModel.pieza.id, fotos: viewModel.fotos) {
                        Task {
                            await viewModel.refrescarFotos()
                            onFotosCambiadas()
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(YonkeTheme.accentRed)
                    }
                }
            }
            .yonkeGroupedBackground()
            .navigationTitle("Confirmar pieza")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: cola.exitosas) {
                Task { await viewModel.refrescarFotos() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            if let actualizada = await viewModel.confirmar() {
                                onConfirmada(actualizada)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.puedeGuardar)
                }
            }
        }
    }
}
