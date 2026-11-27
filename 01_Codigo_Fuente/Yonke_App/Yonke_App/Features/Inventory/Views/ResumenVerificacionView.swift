import SwiftUI

// MARK: - ResumenVerificacionView
/// Resumen al terminar el recorrido: piezas aceptadas, con botones para confirmar
/// o agregar una pieza que no está en el catálogo.

struct ResumenVerificacionView: View {
    @ObservedObject var viewModel: VerificacionPiezasViewModel
    let onAgregar: () -> Void

    var body: some View {
        List {
            Section {
                LabeledContent("Piezas a agregar", value: "\(viewModel.aceptadas.count)")
                LabeledContent("Descartadas", value: "\(viewModel.descartadas)")
            }

            Section {
                if viewModel.aceptadas.isEmpty {
                    Text("No aceptaste ninguna pieza.")
                        .foregroundStyle(YonkeTheme.textSecondary)
                }
                ForEach(viewModel.aceptadas) { pieza in
                    filaPieza(pieza)
                }
            } header: {
                Text("Piezas a agregar")
            } footer: {
                Text("Las piezas sin precio o condición quedan por confirmar en Inventario.")
            }

            Section {
                Button {
                    onAgregar()
                } label: {
                    Label("Agregar pieza fuera de catálogo", systemImage: "plus.circle.fill")
                }
                .disabled(viewModel.isWorking)
            }

            Section {
                Button {
                    Task { await viewModel.confirmar() }
                } label: {
                    Label("Confirmar piezas", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(YonkeTheme.accentGreen)
                .disabled(!viewModel.puedeConfirmar)

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(YonkeTheme.accentRed)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func filaPieza(_ pieza: PiezaInventario) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pieza.nombre)
                    .font(.body)
                    .foregroundStyle(YonkeTheme.textPrimary)
                Text(detalle(pieza))
                    .font(.caption)
                    .foregroundStyle(YonkeTheme.textSecondary)
            }

            Spacer(minLength: 8)

            if pieza.precioVenta == nil || pieza.condicion == nil {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(YonkeTheme.accentYellow)
                    .accessibilityLabel("Quedará por confirmar")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func detalle(_ pieza: PiezaInventario) -> String {
        let precio = pieza.precioVenta.map { $0.formatted(.currency(code: "MXN")) } ?? "Sin precio"
        let condicion = pieza.condicion?.label ?? "Sin condición"
        return "\(precio) · \(condicion)"
    }
}
