import SwiftUI

// MARK: - VehicleRowCard
/// Fila de un vehículo del yonque. El chevron viene de NavigationLink.

struct VehicleRowCard: View {
    let vehiculo: VehiculoInventario

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.title3)
                .foregroundStyle(YonkeTheme.accentRed)
                .frame(width: 44, height: 44)
                .background(YonkeTheme.accentRed.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(vehiculo.titulo)
                    .font(.headline)
                    .foregroundStyle(YonkeTheme.textPrimary)

                if let vin = vehiculo.vin, !vin.isEmpty {
                    Text("VIN: \(vin)")
                        .font(.caption.monospaced())
                        .foregroundStyle(YonkeTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
