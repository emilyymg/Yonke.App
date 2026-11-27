import SwiftUI

// MARK: - TagPill
/// Small colored label used for categories, conditions, and statuses.

struct TagPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: .rect(cornerRadius: 6))
    }
}
