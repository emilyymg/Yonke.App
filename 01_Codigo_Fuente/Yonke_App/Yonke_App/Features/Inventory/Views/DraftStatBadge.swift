import SwiftUI

// MARK: - DraftStatBadge
/// Compact count for one draft status.

struct DraftStatBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(label)
                .font(.caption.bold())
                .foregroundStyle(YonkeTheme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(count, format: .number)
                .font(.subheadline.bold())
                .foregroundStyle(YonkeTheme.textPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .yonkeCard(cornerRadius: 8)
        .accessibilityElement(children: .combine)
    }
}
