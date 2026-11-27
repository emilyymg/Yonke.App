import SwiftUI

// MARK: - AgregarPiezaManualSheet
/// Crea una pieza fuera de plantilla para un vehículo existente del yonque.

struct AgregarPiezaManualSheet: View {
    let onCreada: (PiezaInventario) -> Void

    @StateObject private var viewModel: AgregarPiezaManualViewModel
    @Environment(\.dismiss) private var dismiss

    init(vehiculosIniciales: [VehiculoInventario] = [],
         onCreada: @escaping (PiezaInventario) -> Void) {
        self.onCreada = onCreada
        _viewModel = StateObject(wrappedValue: AgregarPiezaManualViewModel(vehiculosIniciales: vehiculosIniciales))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehículo") {
                    if viewModel.isLoading && viewModel.vehiculos.isEmpty {
                        ProgressView("Cargando vehículos…")
                    } else if viewModel.vehiculos.isEmpty {
                        Text("Primero registra un vehículo para asignarle una pieza.")
                            .font(.subheadline)
                            .foregroundStyle(YonkeTheme.textSecondary)
                    } else {
                        Picker("Vehículo", selection: $viewModel.vehiculoId) {
                            Text("Selecciona").tag(String?.none)
                            ForEach(viewModel.vehiculos) { vehiculo in
                                Text(vehiculo.titulo).tag(String?.some(vehiculo.id))
                            }
                        }
                    }
                }

                Section("Pieza") {
                    TextField("Nombre de la pieza", text: $viewModel.nombre)
                    TextField("Descripción (opcional)", text: $viewModel.descripcion, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    LabeledContent("Precio (MXN)") {
                        TextField("Opcional", text: $viewModel.precioTexto)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Estado de la pieza", selection: $viewModel.condicion) {
                        Text("Sin especificar").tag(CondicionPieza?.none)
                        ForEach(CondicionPieza.allCases) { condicion in
                            Text(condicion.label).tag(CondicionPieza?.some(condicion))
                        }
                    }
                } header: {
                    Text("Precio y condición (opcional)")
                } footer: {
                    Text("Se crea por confirmar con su SKU automático. Luego podrás agregar fotos y confirmarla.")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(YonkeTheme.accentRed)
                    }
                }
            }
            .yonkeGroupedBackground()
            .navigationTitle("Agregar pieza manual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            if let creada = await viewModel.guardar() {
                                onCreada(creada)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.puedeGuardar)
                }
            }
            .task { await viewModel.cargarVehiculosSiFaltan() }
        }
    }
}

