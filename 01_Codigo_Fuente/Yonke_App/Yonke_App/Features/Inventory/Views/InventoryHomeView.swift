import SwiftUI

// MARK: - InventoryHomeView
/// Pestaña Inventario (solo lectura): piezas agrupadas por vehículo,
/// filtro por estado, búsqueda por nombre o SKU y detalle con galería.

struct InventoryHomeView: View {
    @Binding var filtroSolicitado: EstadoPieza?

    @StateObject private var viewModel = InventoryHomeViewModel()
    @State private var mostrarRegistro = false
    @State private var mostrarPiezaManual = false
    @State private var mostrarEscaner = false
    @State private var ruta = NavigationPath()
    @State private var vehiculoAEliminar: VehiculoInventario?

    init(filtroSolicitado: Binding<EstadoPieza?> = .constant(nil)) {
        _filtroSolicitado = filtroSolicitado
    }

    var body: some View {
        NavigationStack(path: $ruta) {
            List {
                Section {
                    estadoPicker
                }

                ForEach(viewModel.grupos) { grupo in
                    Section {
                        ForEach(grupo.piezas) { pieza in
                            NavigationLink(value: pieza) {
                                PiezaRowView(pieza: pieza)
                            }
                        }
                    } header: {
                        HStack {
                            Text(grupo.vehiculo.titulo)
                            Spacer(minLength: 8)
                            Menu {
                                Button("Eliminar vehículo", systemImage: "trash", role: .destructive) {
                                    vehiculoAEliminar = grupo.vehiculo
                                }
                            } label: {
                                Label("Opciones del vehículo", systemImage: "ellipsis.circle")
                                    .labelStyle(.iconOnly)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .yonkeGroupedBackground()
            .navigationTitle("Inventario")
            .searchable(text: $viewModel.searchText, prompt: "Nombre o SKU")
            .navigationDestination(for: PiezaInventario.self) { pieza in
                PiezaDetailView(
                    pieza: pieza,
                    vehiculo: viewModel.vehiculo(id: pieza.vehiculoId),
                    onCambio: { viewModel.actualizar($0) }
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Escanear SKU", systemImage: "viewfinder") {
                        mostrarEscaner = true
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Registrar vehículo", systemImage: "car.fill") {
                            mostrarRegistro = true
                        }
                        Button("Agregar pieza manual", systemImage: "wrench.and.screwdriver.fill") {
                            mostrarPiezaManual = true
                        }
                    } label: {
                        Label("Agregar", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $mostrarEscaner) {
                EscanerSKUSheet { pieza in
                    mostrarEscaner = false
                    ruta.append(pieza)
                }
            }
            .sheet(isPresented: $mostrarRegistro) {
                RegistrarVehiculoSheet { _ in
                    Task { await viewModel.didRegistrar() }
                }
            }
            .sheet(isPresented: $mostrarPiezaManual) {
                AgregarPiezaManualSheet(vehiculosIniciales: viewModel.vehiculos) { creada in
                    viewModel.didCrearPiezaManual(creada)
                    ruta.append(creada)
                }
            }
            .overlay {
                contentOverlay
            }
            .refreshable {
                await viewModel.load()
            }
            .task {
                if let filtro = filtroSolicitado {
                    filtroSolicitado = nil
                    viewModel.estadoFiltro = filtro
                }
                await viewModel.load()
            }
            .onChange(of: filtroSolicitado) {
                aplicarFiltroSolicitado()
            }
            .onChange(of: viewModel.estadoFiltro) {
                Task { await viewModel.reloadPiezas() }
            }
            .confirmationDialog(
                "¿Eliminar este vehículo?",
                isPresented: Binding(
                    get: { vehiculoAEliminar != nil },
                    set: { if !$0 { vehiculoAEliminar = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Eliminar vehículo", role: .destructive) {
                    guard let vehiculo = vehiculoAEliminar else { return }
                    vehiculoAEliminar = nil
                    Task { await viewModel.eliminarVehiculo(id: vehiculo.id) }
                }
            } message: {
                Text("Sus publicaciones activas o pausadas se eliminarán y sus borradores abiertos se descartarán.")
            }
            .alert(
                "No se pudo eliminar",
                isPresented: Binding(
                    get: { viewModel.accionError != nil },
                    set: { if !$0 { viewModel.accionError = nil } }
                )
            ) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(viewModel.accionError ?? "")
            }
        }
    }

    // MARK: - Filtro

    private var estadoPicker: some View {
        Picker("Estado", selection: $viewModel.estadoFiltro) {
            Text("Todas las piezas").tag(EstadoPieza?.none)
            ForEach(EstadoPieza.allCases) { estado in
                Text(estado.label).tag(EstadoPieza?.some(estado))
            }
        }
        .pickerStyle(.menu)
    }

    private func aplicarFiltroSolicitado() {
        guard let filtro = filtroSolicitado else { return }
        filtroSolicitado = nil
        ruta = NavigationPath()
        if viewModel.estadoFiltro != filtro {
            viewModel.estadoFiltro = filtro
        } else {
            Task { await viewModel.reloadPiezas() }
        }
    }

    // MARK: - Estados vacíos

    @ViewBuilder
    private var contentOverlay: some View {
        if viewModel.isLoading && viewModel.grupos.isEmpty {
            ProgressView("Cargando inventario…")
        } else if let error = viewModel.errorMessage, viewModel.grupos.isEmpty {
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Reintentar") {
                    Task { await viewModel.load() }
                }
            }
        } else if viewModel.grupos.isEmpty {
            if viewModel.searchText.isEmpty {
                ContentUnavailableView(
                    "Sin piezas",
                    systemImage: "shippingbox",
                    description: Text("No hay piezas con este estado en tu yonque.")
                )
            } else {
                ContentUnavailableView.search
            }
        }
    }
}
