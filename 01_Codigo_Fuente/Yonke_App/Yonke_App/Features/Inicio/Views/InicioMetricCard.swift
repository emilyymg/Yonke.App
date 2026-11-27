import SwiftUI

// MARK: - InicioMetricCard
/// Tarjeta tocable de métrica en el resumen del yonque.

struct InicioMetricCard: View {
    let titulo: String
    let valor: Int
    let icono: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icono)
                        .foregroundStyle(color)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(YonkeTheme.textMuted)
                }

                Text("\(valor)")
                    .font(.title2.bold())
                    .foregroundStyle(YonkeTheme.textPrimary)

                Text(titulo)
                    .font(.caption.bold())
                    .foregroundStyle(YonkeTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .yonkeCard(cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

