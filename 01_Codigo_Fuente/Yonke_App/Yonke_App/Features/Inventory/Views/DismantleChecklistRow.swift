import SwiftUI

// MARK: - DismantleChecklistRow
/// Checklist row: a selection button, the part name, a condition menu, and a price field.
/// The checkbox is a real Button so VoiceOver announces it as a selectable control.

struct DismantleChecklistRow: View {
    @Binding var row: DismantleRow

    private static let conditions: [PartCondition] = [.excellent, .good, .fair, .broken]

    var body: some View {
        HStack(spacing: 12) {
            Button {
                row.isSelected.toggle()
            } label: {
                Image(systemName: row.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(row.isSelected ? YonkeTheme.accentGreen : YonkeTheme.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.name)
            .accessibilityValue(row.isSelected ? "Seleccionada" : "No seleccionada")
            .accessibilityAddTraits(row.isSelected ? .isSelected : [])

            Image(systemName: YonkeTheme.iconName(for: row.category))
                .foregroundStyle(YonkeTheme.tagColor(for: row.category))
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(row.name)
                .font(.body)
                .foregroundStyle(row.isSelected ? YonkeTheme.textPrimary : YonkeTheme.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 4)

            Picker("Condición", selection: $row.condition) {
                ForEach(Self.conditions, id: \.self) { condition in
                    Text(YonkeTheme.conditionLabel(condition)).tag(condition)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(YonkeTheme.conditionColor(row.condition))

            TextField("Precio", value: $row.price, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.callout.monospaced().bold())
                .foregroundStyle(YonkeTheme.accentGreen)
                .frame(width: 72)
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.15), value: row.isSelected)
    }
}
