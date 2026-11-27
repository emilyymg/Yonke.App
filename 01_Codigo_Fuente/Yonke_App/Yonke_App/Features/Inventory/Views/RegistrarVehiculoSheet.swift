import SwiftUI

// MARK: - RegistrarVehiculoSheet
/// Alta de vehículo con marca, modelo y año del catálogo.
/// Al registrar, la base genera las piezas por confirmar.

struct RegistrarVehiculoSheet: View {
    let onRegistrado: (RegistroVehiculoResultado) -> Void

    @StateObject private var viewModel = RegistrarVehiculoViewModel()
    @Environment(\.dismiss) private var dismiss
    /// Verificación abierta tras registrar. Al cerrarla, termina el alta.
    @State private var verificacion: VerificacionRef?
    @State private var registrado: RegistroVehiculoResultado?

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehículo") {
                    if viewModel.isLoading && viewModel.marcas.isEmpty {
                        ProgressView("Cargando catálogo…")
                    } else {
                        Picker("Marca", selection: $viewModel.marcaId) {
                            Text("Selecciona").tag(String?.none)
                            ForEach(viewModel.marcas) { marca in
                                Text(marca.nombre).tag(String?.some(marca.id))
                            }
                        }

                        Picker("Modelo", selection: $viewModel.modeloId) {
                            Text(viewModel.marcaId == nil ? "Elige una marca primero" : "Selecciona")
                                .tag(String?.none)
                            ForEach(viewModel.modelos) { modelo in
                                Text(modelo.nombre).tag(String?.some(modelo.id))
                            }
                        }
                        .disabled(viewModel.marcaId == nil)

                        Picker("Año", selection: $viewModel.anio) {
                            ForEach(viewModel.aniosDisponibles, id: \.self) { anio in
                                Text(String(anio)).tag(anio)
                            }
                        }
                    }
                }

                Section {
                    Text("Al registrar, se abre la verificación para revisar cada pieza del vehículo.")
                        .font(.footnote)
                        .foregroundStyle(YonkeTheme.textSecondary)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(YonkeTheme.accentRed)
                    }
                }
            }
            .yonkeGroupedBackground()
            .navigationTitle("Registrar vehículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Registrar") {
                        Task {
                            if let resultado = await viewModel.registrar() {
                                registrado = resultado
                                verificacion = VerificacionRef(id: resultado.vehiculoId)
                            }
                        }
                    }
                    .disabled(!viewModel.puedeRegistrar)
                }
            }
            .task { await viewModel.cargarMarcas() }
            .onChange(of: viewModel.marcaId) {
                Task { await viewModel.marcaSeleccionada() }
            }
            .sheet(item: $verificacion, onDismiss: terminarAlta) { ref in
                VerificacionPiezasView(vehiculoId: ref.id)
            }
        }
    }

    /// Cierra el alta cuando termina la verificación (o se cierra antes de terminarla).
    private func terminarAlta() {
        guard let resultado = registrado else { return }
        registrado = nil
        onRegistrado(resultado)
        dismiss()
    }
}
