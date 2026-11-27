import SwiftUI

// MARK: - BorradorDescartadoView
/// Detalle de un borrador descartado. Se puede restaurar a Borradores para editarlo y publicarlo.

struct BorradorDescartadoView: View {
    @State private var borrador: Borrador
    @State private var procesando = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let service: PublicacionServiceProtocol
    private let onCambio: () -> Void

    init(borrador: Borrador,
         service: PublicacionServiceProtocol = RemotePublicacionService.shared,
         onCambio: @escaping () -> Void = {}) {
        _borrador = State(initialValue: borrador)
        self.service = service
        self.onCambio = onCambio
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FotoThumbnail(url: borrador.fotoThumbUrl, size: 220)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(borrador.titulo ?? borrador.piezaNombre)
                            .font(.title2.bold())
                            .foregroundStyle(YonkeTheme.textPrimary)
                        Spacer(minLength: 8)
                        TagPill(text: borrador.estado.label, color: borrador.estado.color)
                    }
                    if let precio = borrador.precioPublico {
                        Text(precio.formatted(.currency(code: "MXN")))
                            .font(.title3.bold())
                            .foregroundStyle(YonkeTheme.accentGreen)
                    }
                }

                acciones

                datos

                if let motivo = borrador.motivoDescarte, !motivo.isEmpty {
                    tarjeta(titulo: "Motivo del descarte", texto: motivo)
                }

                if let descripcion = borrador.descripcionMarketplace, !descripcion.isEmpty {
                    tarjeta(titulo: "Descripción", texto: descripcion)
                }
            }
            .padding()
        }
        .background(YonkeTheme.background.ignoresSafeArea())
        .navigationTitle("Borrador")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Acciones

    private var acciones: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(YonkeTheme.accentRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Restaurar a borradores", systemImage: "arrow.uturn.backward.circle.fill") {
                restaurar()
            }
            .buttonStyle(.borderedProminent)
            .tint(YonkeTheme.accentBlue)
            .controlSize(.large)

            Text("Vuelve a Borradores para revisarlo y publicarlo de nuevo.")
                .font(.footnote)
                .foregroundStyle(YonkeTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .disabled(procesando)
    }

    private func restaurar() {
        guard !procesando else { return }
        procesando = true
        errorMessage = nil
        Task {
            defer { procesando = false }
            do {
                _ = try await service.reabrirBorrador(id: borrador.id)
                onCambio()
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo restaurar el borrador."
            }
        }
    }

    // MARK: - Datos

    private var datos: some View {
        VStack(spacing: 0) {
            fila("Pieza", valor: borrador.piezaNombre)
            if let sku = borrador.piezaSku {
                Divider().overlay(YonkeTheme.cardBorder)
                fila("SKU", valor: sku, monospaced: true)
            }
            if let vehiculo = borrador.vehiculoTitulo {
                Divider().overlay(YonkeTheme.cardBorder)
                fila("Vehículo", valor: vehiculo)
            }
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Condición", valor: borrador.condicionPublicada?.label ?? "Sin especificar")
        }
        .padding(.horizontal, 16)
        .yonkeCard(cornerRadius: 12)
    }

    private func tarjeta(titulo: String, texto: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.headline)
                .foregroundStyle(YonkeTheme.textPrimary)
            Text(texto)
                .font(.body)
                .foregroundStyle(YonkeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .yonkeCard(cornerRadius: 12)
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
}
