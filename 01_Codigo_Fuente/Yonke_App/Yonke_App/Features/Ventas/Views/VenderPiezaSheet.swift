import SwiftUI

// MARK: - VenderPiezaSheet
/// Registra la venta de una pieza disponible o reservada. Cierra la publicación
/// activa y deja la pieza como vendida.

struct VenderPiezaSheet: View {
    let onVendida: (Venta) -> Void

    @StateObject private var viewModel: VenderPiezaViewModel
    @Environment(\.dismiss) private var dismiss

    init(pieza: PiezaInventario, onVendida: @escaping (Venta) -> Void) {
        self.onVendida = onVendida
        _viewModel = StateObject(wrappedValue: VenderPiezaViewModel(pieza: pieza))
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

                Section("Venta") {
                    LabeledContent("Precio final (MXN)") {
                        TextField("0.00", text: $viewModel.precioTexto)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Método de pago", selection: $viewModel.metodoPago) {
                        ForEach(MetodoPago.allCases) { metodo in
                            Text(metodo.label).tag(metodo)
                        }
                    }
                }

                Section("Comprador (opcional)") {
                    TextField("Nombre", text: $viewModel.compradorNombre)
                        .textContentType(.name)
                    TextField("Notas", text: $viewModel.notas, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(YonkeTheme.accentRed)
                    }
                }
            }
            .yonkeGroupedBackground()
            .navigationTitle("Vender pieza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Registrar venta") {
                        Task {
                            if let venta = await viewModel.registrar() {
                                onVendida(venta)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.puedeRegistrar)
                }
            }
        }
    }
}
