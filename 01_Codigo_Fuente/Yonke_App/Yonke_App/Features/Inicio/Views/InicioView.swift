import SwiftUI

// MARK: - InicioView
/// Pestaña Inicio: resumen del yonque, alertas de inventario, acceso a vehículos y ventas recientes.

struct InicioView: View {
    let onIrAInventario: (EstadoPieza?) -> Void
    let onIrAPublicaciones: () -> Void
    let onIrAVentas: () -> Void

    @StateObject private var viewModel = InicioViewModel()
    @State private var ruta = NavigationPath()
    @State private var mostrarRegistro = false
    @State private var mostrarEscaner = false

    private let columnas = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $ruta) {
            List {
                if viewModel.yonque != nil {
                    resumenSection
                    if viewModel.tieneAlertas {
                        alertasSection
                    }
                    vehiculosSection
                    ventasSection
                }
            }
            .listStyle(.insetGrouped)
            .yonkeGroupedBackground()
            .navigationTitle("Inicio")
            .navigationSubtitle(viewModel.yonque?.nombre ?? "")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Escanear SKU", systemImage: "viewfinder") {
                        mostrarEscaner = true
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Registrar vehículo", systemImage: "plus") {
                        mostrarRegistro = true
                    }
                }
            }
            .navigationDestination(for: InicioDestino.self) { destino in
                switch destino {
                case .vehiculos:
                    VehicleListView()
                }
            }
            .navigationDestination(for: Venta.self) { venta in
                VentaDetailView(venta: venta) {
                    Task { await viewModel.load() }
                }
            }
            .navigationDestination(for: PiezaInventario.self) { pieza in
                PiezaDetailView(
                    pieza: pieza,
                    vehiculo: viewModel.vehiculo(id: pieza.vehiculoId),
                    onCambio: { _ in Task { await viewModel.load() } }
                )
            }
            .sheet(isPresented: $mostrarEscaner) {
                EscanerSKUSheet { pieza in
                    mostrarEscaner = false
                    ruta.append(pieza)
                }
            }
            .sheet(isPresented: $mostrarRegistro) {
                RegistrarVehiculoSheet { _ in
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

    private var resumenSection: some View {
        Section {
            LazyVGrid(columns: columnas, spacing: 12) {
                InicioMetricCard(
                    titulo: "Por confirmar",
                    valor: viewModel.piezasPorConfirmar,
                    icono: "clock.badge.exclamationmark",
                    color: YonkeTheme.accentYellow
                ) {
                    onIrAInventario(.porConfirmar)
                }

                InicioMetricCard(
                    titulo: "Disponibles",
                    valor: viewModel.piezasDisponibles,
                    icono: "shippingbox.fill",
                    color: YonkeTheme.accentGreen
                ) {
                    onIrAInventario(.disponible)
                }

                InicioMetricCard(
                    titulo: "Publicadas",
                    valor: viewModel.publicacionesActivas,
                    icono: "megaphone.fill",
                    color: YonkeTheme.accentRed
                ) {
                    onIrAPublicaciones()
                }

                InicioMetricCard(
                    titulo: "Vehículos",
                    valor: viewModel.totalVehiculos,
                    icono: "car.fill",
                    color: YonkeTheme.accentBlue
                ) {
                    ruta.append(InicioDestino.vehiculos)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Alertas

    private var alertasSection: some View {
        Section("Alertas") {
            if viewModel.piezasPorConfirmar > 0 {
                alertaFila(
                    titulo: "\(viewModel.piezasPorConfirmar) piezas por confirmar",
                    detalle: "Revísalas para dejarlas disponibles.",
                    icono: "exclamationmark.circle.fill",
                    color: YonkeTheme.accentYellow
                ) {
                    onIrAInventario(.porConfirmar)
                }
            }

            if viewModel.alertaInventarioBajo {
                alertaFila(
                    titulo: viewModel.piezasDisponibles == 0
                        ? "Sin piezas disponibles"
                        : "Inventario bajo (\(viewModel.piezasDisponibles) disponibles)",
                    detalle: "Registra un vehículo o confirma piezas pendientes.",
                    icono: "exclamationmark.triangle.fill",
                    color: YonkeTheme.accentOrange
                ) {
                    mostrarRegistro = true
                }
            }

            if viewModel.alertaSinPublicar {
                alertaFila(
                    titulo: "Piezas disponibles sin publicar",
                    detalle: "Crea borradores desde el detalle en Inventario.",
                    icono: "megaphone.fill",
                    color: YonkeTheme.accentBlue
                ) {
                    onIrAInventario(.disponible)
                }
            }
        }
    }

    private func alertaFila(
        titulo: String,
        detalle: String,
        icono: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icono)
                    .foregroundStyle(color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(.subheadline.bold())
                        .foregroundStyle(YonkeTheme.textPrimary)
                    Text(detalle)
                        .font(.caption)
                        .foregroundStyle(YonkeTheme.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(YonkeTheme.textMuted)
            }
            .padding(.vertical, 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vehículos

    private var vehiculosSection: some View {
        Section("Vehículos") {
            NavigationLink(value: InicioDestino.vehiculos) {
                HStack(spacing: 12) {
                    Image(systemName: "car.2.fill")
                        .foregroundStyle(YonkeTheme.accentBlue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vehículos del yonque")
                            .foregroundStyle(YonkeTheme.textPrimary)
                        Text("\(viewModel.totalVehiculos) registrados")
                            .font(.caption)
                            .foregroundStyle(YonkeTheme.textSecondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Ventas recientes

    private var ventasSection: some View {
        Section("Ventas recientes") {
            if viewModel.ventasRecientes.isEmpty {
                Text("Aún no hay ventas registradas.")
                    .font(.subheadline)
                    .foregroundStyle(YonkeTheme.textSecondary)
            } else {
                ForEach(viewModel.ventasRecientes) { venta in
                    NavigationLink(value: venta) {
                        VentaRowView(venta: venta)
                    }
                }

                Button("Ver todas las ventas") {
                    onIrAVentas()
                }
            }
        }
    }

    // MARK: - Estados vacíos

    @ViewBuilder
    private var contentOverlay: some View {
        if viewModel.isLoading && viewModel.yonque == nil {
            ProgressView("Cargando resumen…")
        } else if let error = viewModel.errorMessage, viewModel.yonque == nil {
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Reintentar") {
                    Task { await viewModel.load() }
                }
            }
        }
    }
}

