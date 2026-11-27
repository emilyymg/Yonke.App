import SwiftUI

// MARK: - Estado de pieza (color)

extension EstadoPieza {
    var color: Color {
        switch self {
        case .porConfirmar: return YonkeTheme.accentYellow
        case .disponible:   return YonkeTheme.accentGreen
        case .reservado:    return YonkeTheme.accentOrange
        case .vendido:      return YonkeTheme.textMuted
        case .descartado:   return YonkeTheme.accentRed
        case .enRevision:   return YonkeTheme.accentBlue
        }
    }
}

// MARK: - FotoThumbnail
/// Miniatura de la foto principal (derivado `thumb`). Sin URL o con error muestra un placeholder.

struct FotoThumbnail: View {
    let url: URL?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 10))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            YonkeTheme.surfaceElevated
            Image(systemName: "photo")
                .foregroundStyle(YonkeTheme.textMuted)
        }
    }
}

// MARK: - PiezaRowView

struct PiezaRowView: View {
    let pieza: PiezaInventario

    var body: some View {
        HStack(spacing: 12) {
            FotoThumbnail(url: pieza.fotoPrincipal?.thumbUrl)

            VStack(alignment: .leading, spacing: 4) {
                Text(pieza.nombre)
                    .font(.headline)
                    .foregroundStyle(YonkeTheme.textPrimary)
                    .lineLimit(2)

                if let sku = pieza.sku {
                    Text(sku)
                        .font(.caption.monospaced())
                        .foregroundStyle(YonkeTheme.textMuted)
                        .lineLimit(1)
                }

                if let precio = pieza.precioVenta {
                    Text(precio.formatted(.currency(code: "MXN")))
                        .font(.subheadline.bold())
                        .foregroundStyle(YonkeTheme.accentGreen)
                } else {
                    Text("Sin precio")
                        .font(.caption)
                        .foregroundStyle(YonkeTheme.textMuted)
                }
            }

            Spacer(minLength: 8)

            TagPill(text: pieza.estado.label, color: pieza.estado.color)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
