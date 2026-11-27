import SwiftUI

// MARK: - VentaDetailView
/// Detalle de una venta. Solo las completadas se pueden devolver; la pieza vuelve a disponible.

struct VentaDetailView: View {
    let onCambio: () -> Void

    @State private var venta: Venta
    @State private var confirmarDevolucion = false
    @State private var trabajando = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let service: VentaServiceProtocol

    init(venta: Venta,
         service: VentaServiceProtocol = RemoteVentaService.shared,
         onCambio: @escaping () -> Void = {}) {
        _venta = State(initialValue: venta)
        self.service = service
        self.onCambio = onCambio
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                encabezado
                datos

                if let notas = venta.notas, !notas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notas")
                            .font(.headline)
                            .foregroundStyle(YonkeTheme.textPrimary)
                        Text(notas)
                            .font(.body)
                            .foregroundStyle(YonkeTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .yonkeCard(cornerRadius: 12)
                }

                if venta.estado == .completada {
                    devolverBoton
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(YonkeTheme.accentRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(YonkeTheme.background.ignoresSafeArea())
        .navigationTitle("Venta")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Devolver esta venta?", isPresented: $confirmarDevolucion, titleVisibility: .visible) {
            Button("Devolver venta", role: .destructive) {
                Task { await devolver() }
            }
        } message: {
            Text("La pieza volverá a estar disponible en el inventario. La publicación seguirá cerrada como vendida.")
        }
    }

    // MARK: - Secciones

    private var encabezado: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(venta.piezaNombre)
                .font(.title2.bold())
                .foregroundStyle(YonkeTheme.textPrimary)
            Spacer(minLength: 8)
            TagPill(text: venta.estado.label, color: venta.estado.color)
        }
    }

    private var datos: some View {
        VStack(spacing: 0) {
            fila("Precio final", valor: venta.precioFinal.formatted(.currency(code: "MXN")))
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Método de pago", valor: venta.metodoPago.label)
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Comprador", valor: venta.compradorNombre ?? "Sin comprador")
            if let sku = venta.piezaSku {
                Divider().overlay(YonkeTheme.cardBorder)
                fila("SKU", valor: sku, monospaced: true)
            }
            if let vehiculo = venta.vehiculoTitulo {
                Divider().overlay(YonkeTheme.cardBorder)
                fila("Vehículo", valor: vehiculo)
            }
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Fecha", valor: venta.fechaVenta.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(.horizontal, 16)
        .yonkeCard(cornerRadius: 12)
    }

    private var devolverBoton: some View {
        Button(role: .destructive) {
            confirmarDevolucion = true
        } label: {
            Label("Devolver venta", systemImage: "arrow.uturn.left.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(trabajando)
    }

    private func fila(_ titulo: String, valor: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(titulo)
                .foregroundStyle(YonkeTheme.textSecondary)
            Spacer(minLength: 12)
            Text(valor)
                .font(monospaced ? .body.monospaced() : .body)
                .foregroundStyle(YonkeTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Acciones

    private func devolver() async {
        trabajando = true
        errorMessage = nil
        defer { trabajando = false }

        do {
            venta = try await service.devolverVenta(id: venta.id)
            onCambio()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo devolver la venta."
        }
    }
}
