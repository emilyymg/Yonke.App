import SwiftUI

// MARK: - PartCardView
/// Card for a single extracted part: category, name, tags, price, availability.

struct PartCardView: View {
    let part: Part

    private var categoryColor: Color {
        YonkeTheme.tagColor(for: part.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: YonkeTheme.iconName(for: part.category))
                    .font(.title2)
                    .foregroundStyle(categoryColor)
                    .accessibilityHidden(true)

                Spacer()

                if part.isSold {
                    Text("VENDIDO")
                        .font(.caption.bold())
                        .foregroundStyle(YonkeTheme.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(YonkeTheme.accentRed, in: .rect(cornerRadius: 4))
                }
            }

            Text(part.name)
                .font(.headline)
                .foregroundStyle(YonkeTheme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                TagPill(text: part.category, color: categoryColor)
                TagPill(text: YonkeTheme.conditionLabel(part.condition),
                        color: YonkeTheme.conditionColor(part.condition))
            }

            Spacer(minLength: 0)

            Text(YonkeTheme.formatPrice(part.price))
                .font(.title3.bold())
                .foregroundStyle(YonkeTheme.accentGreen)

            Label(
                part.isSold ? "No disponible" : "Disponible",
                systemImage: part.isSold ? "xmark.circle.fill" : "checkmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(part.isSold ? YonkeTheme.accentRed : YonkeTheme.accentGreen)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .yonkeCard()
        .accessibilityElement(children: .combine)
    }
}
