import SwiftUI

// MARK: - VehicleDetailView
/// Detalle de un vehículo del yonque: datos del catálogo y sus piezas.

struct VehicleDetailView: View {
    let vehiculo: VehiculoInventario

    @State private var piezas: [PiezaInventario] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service: InventoryServiceProtocol

    init(vehiculo: VehiculoInventario, service: InventoryServiceProtocol = RemoteInventoryService.shared) {
        self.vehiculo = vehiculo
        self.service = service
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                datos
                piezasSection
            }
            .padding()
        }
        .background(YonkeTheme.background.ignoresSafeArea())
        .navigationTitle(vehiculo.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargarPiezas() }
        .refreshable { await cargarPiezas() }
    }

    // MARK: - Datos del vehículo

    private var datos: some View {
        VStack(spacing: 0) {
            fila("Marca", valor: vehiculo.marca)
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Modelo", valor: vehiculo.modelo)
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Año", valor: String(vehiculo.anio))
            if let vin = vehiculo.vin, !vin.isEmpty {
                Divider().overlay(YonkeTheme.cardBorder)
                fila("VIN", valor: vin, monospaced: true)
            }
        }
        .padding(.horizontal, 16)
        .yonkeCard(cornerRadius: 12)
    }

    private func fila(_ titulo: String, valor: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(titulo)
                .foregroundStyle(YonkeTheme.textSecondary)
            Spacer(minLength: 12)
            Text(valor)
                .font(monospaced ? .body.monospaced() : .body)
                .foregroundStyle(YonkeTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Piezas

    @ViewBuilder
    private var piezasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Piezas (\(piezas.count))")
                .font(.headline)
                .foregroundStyle(YonkeTheme.textPrimary)

            if isLoading && piezas.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(YonkeTheme.accentRed)
            } else if piezas.isEmpty {
                Text("Este vehículo aún no tiene piezas registradas.")
                    .font(.subheadline)
                    .foregroundStyle(YonkeTheme.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(piezas.enumerated()), id: \.element.id) { indice, pieza in
                        if indice > 0 {
                            Divider().overlay(YonkeTheme.cardBorder)
                        }
                        filaPieza(pieza)
                    }
                }
                .padding(.horizontal, 16)
                .yonkeCard(cornerRadius: 12)
            }
        }
    }

    private func filaPieza(_ pieza: PiezaInventario) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pieza.nombre)
                    .font(.body)
                    .foregroundStyle(YonkeTheme.textPrimary)
                    .lineLimit(2)
                if let sku = pieza.sku {
                    Text(sku)
                        .font(.caption.monospaced())
                        .foregroundStyle(YonkeTheme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            TagPill(text: pieza.estado.label, color: pieza.estado.color)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Carga

    private func cargarPiezas() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // El backend no filtra por vehículo; se filtra aquí sobre las piezas del yonque.
            let todas = try await service.fetchPiezas(estado: nil)
            piezas = todas.filter { $0.vehiculoId == vehiculo.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar las piezas."
        }
    }
}
