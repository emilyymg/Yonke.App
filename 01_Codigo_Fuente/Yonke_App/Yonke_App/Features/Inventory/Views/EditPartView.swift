import SwiftUI

// MARK: - EditPartView
/// Detail/edit screen for a single part, following the dark theme.

struct EditPartView: View {
    let part: Part
    @State private var price: String
    @State private var condition: PartCondition

    init(part: Part) {
        self.part = part
        _price = State(initialValue: String(format: "%.0f", part.price))
        _condition = State(initialValue: part.condition)
    }

    var body: some View {
        ZStack {
            YonkeTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Icon + Name Header
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(YonkeTheme.tagColor(for: part.category).opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: YonkeTheme.iconName(for: part.category))
                                .font(.title2)
                                .foregroundColor(YonkeTheme.tagColor(for: part.category))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(part.name)
                                .font(.title3.bold())
                                .foregroundColor(YonkeTheme.textPrimary)
                            HStack(spacing: 6) {
                                TagPill(text: part.category, color: YonkeTheme.tagColor(for: part.category))
                                TagPill(text: YonkeTheme.conditionLabel(part.condition),
                                        color: YonkeTheme.conditionColor(part.condition))
                            }
                        }
                    }

                    // Description
                    if let desc = part.description {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Descripción")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(YonkeTheme.textSecondary)
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(YonkeTheme.textPrimary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(YonkeTheme.surface)
                        .cornerRadius(10)
                    }

                    // Price & Condition Editors
                    VStack(spacing: 14) {
                        editRow(label: "Precio (MXN)") {
                            TextField("0", text: $price)
                                .keyboardType(.decimalPad)
                                .foregroundColor(YonkeTheme.accentGreen)
                                .font(.headline.monospaced())
                        }

                        editRow(label: "Condición") {
                            Picker("", selection: $condition) {
                                ForEach([PartCondition.excellent, .good, .fair, .broken], id: \.self) { c in
                                    Text(YonkeTheme.conditionLabel(c)).tag(c)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // Status Badge
                    HStack {
                        Text(part.isSold ? "VENDIDO" : "DISPONIBLE")
                            .font(.footnote.bold())
                            .foregroundColor(part.isSold ? YonkeTheme.accentRed : YonkeTheme.accentGreen)
                        Spacer()
                        Text(YonkeTheme.formatPrice(Double(price) ?? part.price))
                            .font(.title2.bold())
                            .foregroundColor(YonkeTheme.accentGreen)
                    }
                    .padding(16)
                    .background(YonkeTheme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(YonkeTheme.cardBorder, lineWidth: 1)
                    )

                    // Save Button
                    Button {
                        // TODO: Implement save via DataServiceProtocol
                    } label: {
                        Text("Guardar Cambios")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(YonkeTheme.accentRed)
                            .cornerRadius(12)
                    }

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func editRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(YonkeTheme.textSecondary)
            content()
        }
        .padding(14)
        .background(YonkeTheme.surface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(YonkeTheme.cardBorder, lineWidth: 1)
        )
    }
}
