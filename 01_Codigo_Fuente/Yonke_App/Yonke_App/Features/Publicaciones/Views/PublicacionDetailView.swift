import SwiftUI

// MARK: - PublicacionDetailView
/// Detalle de una publicación. Pausar, reactivar y eliminar se hacen con el backend;
/// vender se hace desde la pestaña Ventas, porque es lo que cierra la publicación.

struct PublicacionDetailView: View {
    @State private var publicacion: Publicacion
    @State private var procesando = false
    @State private var errorMessage: String?
    @State private var confirmarEliminar = false
    @Environment(\.dismiss) private var dismiss

    private let service: PublicacionServiceProtocol
    private let onCambio: () -> Void

    init(publicacion: Publicacion,
         service: PublicacionServiceProtocol = RemotePublicacionService.shared,
         onCambio: @escaping () -> Void = {}) {
        _publicacion = State(initialValue: publicacion)
        self.service = service
        self.onCambio = onCambio
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FotoThumbnail(url: publicacion.fotoThumbUrl, size: 220)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(publicacion.titulo)
                            .font(.title2.bold())
                            .foregroundStyle(YonkeTheme.textPrimary)
                        Spacer(minLength: 8)
                        TagPill(text: publicacion.estado.label, color: publicacion.estado.color)
                    }
                    Text(publicacion.precio.formatted(.currency(code: "MXN")))
                        .font(.title3.bold())
                        .foregroundStyle(YonkeTheme.accentGreen)
                }

                acciones

                datos

                if let descripcion = publicacion.descripcion, !descripcion.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descripción")
                            .font(.headline)
                            .foregroundStyle(YonkeTheme.textPrimary)
                        Text(descripcion)
                            .font(.body)
                            .foregroundStyle(YonkeTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .yonkeCard(cornerRadius: 12)
                }
            }
            .padding()
        }
        .background(YonkeTheme.background.ignoresSafeArea())
        .navigationTitle("Publicación")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Eliminar esta publicación?", isPresented: $confirmarEliminar, titleVisibility: .visible) {
            Button("Eliminar publicación", role: .destructive) {
                cambiar(a: .eliminada)
            }
        } message: {
            Text("La pieza seguirá en el inventario, pero dejará de verse en el marketplace.")
        }
    }

    // MARK: - Acciones de estado

    @ViewBuilder
    private var acciones: some View {
        if [EstadoPublicacion.activa, .pausada, .eliminada].contains(publicacion.estado) {
            VStack(spacing: 12) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(YonkeTheme.accentRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if publicacion.estado == .activa {
                    Button("Pausar publicación", systemImage: "pause.circle.fill") {
                        cambiar(a: .pausada)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Reactivar publicación", systemImage: "play.circle.fill") {
                        cambiar(a: .activa)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(YonkeTheme.accentGreen)
                }

                if publicacion.estado != .eliminada {
                    Button("Eliminar publicación", systemImage: "trash", role: .destructive) {
                        confirmarEliminar = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(procesando)
        }
    }

    private func cambiar(a nuevo: EstadoPublicacion) {
        guard !procesando else { return }
        procesando = true
        errorMessage = nil
        // Al eliminar o reactivar desde Descartadas, la publicación sale de esa lista.
        let saleDeDescartadas = nuevo == .eliminada || publicacion.estado == .eliminada
        Task {
            defer { procesando = false }
            do {
                let actualizada = try await service.cambiarEstadoPublicacion(id: publicacion.id, nuevo: nuevo)
                onCambio()
                if saleDeDescartadas {
                    dismiss()
                } else {
                    publicacion = actualizada
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cambiar el estado."
            }
        }
    }

    private var datos: some View {
        VStack(spacing: 0) {
            fila("Pieza", valor: publicacion.piezaNombre)
            if let sku = publicacion.piezaSku {
                Divider().overlay(YonkeTheme.cardBorder)
                fila("SKU", valor: sku, monospaced: true)
            }
            if let vehiculo = publicacion.vehiculoTitulo {
                Divider().overlay(YonkeTheme.cardBorder)
                fila("Vehículo", valor: vehiculo)
            }
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Condición", valor: publicacion.condicion?.label ?? "Sin especificar")
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Vistas", valor: "\(publicacion.vistas)")
            if let fecha = publicacion.fechaPublicacion {
                Divider().overlay(YonkeTheme.cardBorder)
                fila("Publicada", valor: fecha.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding(.horizontal, 16)
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
