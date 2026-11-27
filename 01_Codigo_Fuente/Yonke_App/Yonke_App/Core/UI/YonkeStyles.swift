import SwiftUI

// MARK: - Shared surface styling
/// View helpers built on `YonkeTheme` tokens. They replace repeated
/// background + overlay chains. The palette itself stays in `YonkeTheme`.

extension View {
    /// Dark card surface with a thin border.
    func yonkeCard(
        cornerRadius: CGFloat = 12,
        border: Color = YonkeTheme.cardBorder,
        borderWidth: CGFloat = 1
    ) -> some View {
        self
            .background(YonkeTheme.surface, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(border, lineWidth: borderWidth)
            }
    }

    /// Background for List, Form, and ScrollView screens, plus the card-colored rows.
    func yonkeGroupedBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(YonkeTheme.background.ignoresSafeArea())
            .listRowBackground(YonkeTheme.surface)
    }
}
