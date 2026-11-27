import SwiftUI

// MARK: - VentasView
/// Pestaña Ventas: totales del día o del mes y el historial de ventas.

struct VentasView: View {
    @StateObject private var viewModel = VentasViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Periodo", selection: $viewModel.periodo) {
                        ForEach(PeriodoVentas.allCases) { periodo in
                            Text(periodo.rawValue).tag(periodo)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)

                    resumen
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if !viewModel.ventasDelPeriodo.isEmpty {
                    Section("Ventas") {
                        ForEach(viewModel.ventasDelPeriodo) { venta in
                            NavigationLink(value: venta) {
                                VentaRowView(venta: venta)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .yonkeGroupedBackground()
            .navigationTitle("Ventas")
            .navigationDestination(for: Venta.self) { venta in
                VentaDetailView(venta: venta) {
                    Task { await viewModel.load() }
                }
            }
            .overlay {
                contentOverlay
            }
            .refreshable {
                await viewModel.load()
            }
            .onAppear {
                Task { await viewModel.load() }
            }
        }
    }

    // MARK: - Resumen

    private var resumen: some View {
        HStack(spacing: 12) {
            StatCard(
                titulo: "Ingresos",
                valor: viewModel.totalIngresos.formatted(.currency(code: "MXN")),
                color: YonkeTheme.accentGreen
            )
            StatCard(
                titulo: "Ventas",
                valor: "\(viewModel.cantidadCompletadas)",
                color: YonkeTheme.accentPurple
            )
        }
    }

    // MARK: - Estados vacíos

    @ViewBuilder
    private var contentOverlay: some View {
        if viewModel.isLoading && viewModel.ventas.isEmpty {
            ProgressView("Cargando ventas…")
        } else if let error = viewModel.errorMessage, viewModel.ventas.isEmpty {
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Reintentar") {
                    Task { await viewModel.load() }
                }
            }
        } else if viewModel.ventasDelPeriodo.isEmpty {
            ContentUnavailableView(
                viewModel.periodo == .dia ? "Sin ventas hoy" : "Sin ventas este mes",
                systemImage: "banknote",
                description: Text("Las ventas registradas desde el detalle de una pieza aparecen aquí.")
            )
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let titulo: String
    let valor: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.caption.bold())
                .foregroundStyle(YonkeTheme.textSecondary)
            Text(valor)
                .font(.title3.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .yonkeCard(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - VentaRowView

struct VentaRowView: View {
    let venta: Venta

    var body: some View {
        HStack(spacing: 12) {
            FotoThumbnail(url: venta.fotoThumbUrl)

            VStack(alignment: .leading, spacing: 4) {
                Text(venta.piezaNombre)
                    .font(.headline)
                    .foregroundStyle(YonkeTheme.textPrimary)
                    .lineLimit(2)
                Text(venta.compradorNombre ?? "Sin comprador")
                    .font(.caption)
                    .foregroundStyle(YonkeTheme.textSecondary)
                Text(venta.fechaVenta.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(YonkeTheme.textMuted)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(venta.precioFinal.formatted(.currency(code: "MXN")))
                    .font(.subheadline.bold())
                    .foregroundStyle(venta.estado == .completada ? YonkeTheme.accentGreen : YonkeTheme.textMuted)
                TagPill(text: venta.estado.label, color: venta.estado.color)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Colores de estado

extension EstadoVenta {
    var color: Color {
        switch self {
        case .pendiente:  return YonkeTheme.accentYellow
        case .completada: return YonkeTheme.accentGreen
        case .cancelada:  return YonkeTheme.accentRed
        case .devuelta:   return YonkeTheme.accentOrange
        case .garantia:   return YonkeTheme.accentBlue
        }
    }
}
