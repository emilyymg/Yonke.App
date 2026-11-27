import SwiftUI

// MARK: - VehicleListView
/// Pestaña Vehículos: vehículos del yonque, búsqueda y alta desde el catálogo de marcas y modelos.

struct VehicleListView: View {
    @StateObject private var viewModel = VehicleViewModel()
    @State private var showRegistrar = false
    @State private var searchText = ""

    private var filteredVehiculos: [VehiculoInventario] {
        guard !searchText.isEmpty else { return viewModel.vehiculos }
        let query = searchText.lowercased()
        return viewModel.vehiculos.filter {
            $0.marca.lowercased().contains(query) ||
            $0.modelo.lowercased().contains(query) ||
            String($0.anio).contains(query) ||
            ($0.vin?.lowercased().contains(query) == true)
        }
    }

    var body: some View {
        List {
            if !filteredVehiculos.isEmpty {
                Section("Vehículos") {
                    ForEach(filteredVehiculos) { vehiculo in
                        NavigationLink(value: vehiculo) {
                            VehicleRowCard(vehiculo: vehiculo)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .yonkeGroupedBackground()
        .navigationTitle("Vehículos")
        .navigationSubtitle("Gestión de vehículos")
        .searchable(text: $searchText, prompt: "Marca, modelo o VIN")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Registrar vehículo", systemImage: "plus") {
                    showRegistrar = true
                }
            }
        }
        .navigationDestination(for: VehiculoInventario.self) { vehiculo in
            VehicleDetailView(vehiculo: vehiculo)
        }
        .overlay {
            contentOverlay
        }
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $showRegistrar) {
            RegistrarVehiculoSheet { _ in
                Task { await viewModel.load() }
            }
        }
    }

    // MARK: - Estados vacíos

    @ViewBuilder
    private var contentOverlay: some View {
        if viewModel.isLoading && viewModel.vehiculos.isEmpty {
            ProgressView("Cargando vehículos…")
        } else if let error = viewModel.errorMessage, viewModel.vehiculos.isEmpty {
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Reintentar") {
                    Task { await viewModel.load() }
                }
            }
        } else if viewModel.vehiculos.isEmpty {
            ContentUnavailableView(
                "Sin vehículos registrados",
                systemImage: "car.fill",
                description: Text("Toca + para registrar tu primer vehículo.")
            )
        } else if filteredVehiculos.isEmpty {
            ContentUnavailableView.search
        }
    }
}
