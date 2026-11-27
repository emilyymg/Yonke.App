import SwiftUI

// MARK: - DraftThumbnailCard
/// Grid tile for a publication draft. The border and badge use the draft status color.

struct DraftThumbnailCard: View {
    let draft: PublicationDraft

    private var statusColor: Color {
        YonkeTheme.draftStatusColor(draft.estado)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(YonkeTheme.surfaceElevated)
                .overlay(alignment: .topTrailing) {
                    // Dark text on the status fill: white on yellow or green fails contrast.
                    Text(draft.estado.label)
                        .font(.caption.bold())
                        .foregroundStyle(YonkeTheme.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor, in: .rect(cornerRadius: 4))
                        .padding(6)
                }
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.nombre_pieza)
                    .font(.subheadline.bold())
                    .foregroundStyle(YonkeTheme.textPrimary)
                    .lineLimit(1)

                Text("\(draft.marca_vehiculo) \(draft.modelo_vehiculo) \(draft.anio_vehiculo)")
                    .font(.caption)
                    .foregroundStyle(YonkeTheme.textSecondary)
                    .lineLimit(1)

                Text("Color: \(draft.color_pieza.isEmpty ? "N/A" : draft.color_pieza)")
                    .font(.caption)
                    .foregroundStyle(YonkeTheme.textMuted)
                    .lineLimit(1)

                Text("SKU: \(draft.sku_pieza)")
                    .font(.caption.monospaced())
                    .foregroundStyle(YonkeTheme.textMuted)
                    .lineLimit(1)

                Spacer(minLength: 2)

                Text(YonkeTheme.formatPrice(draft.precio_publico))
                    .font(.subheadline.bold())
                    .foregroundStyle(YonkeTheme.accentGreen)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .yonkeCard(cornerRadius: 10)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photo = draft.fotos_inventario.first, let url = URL(string: photo) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
        } else {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
                .foregroundStyle(YonkeTheme.textMuted)
        }
    }
}
