import SwiftUI

// MARK: - PublicacionesView
/// Pestaña Publicaciones. Borradores abiertos para editar y publicar, y publicaciones
/// filtradas por estado (activa, pausada, vendida).

struct PublicacionesView: View {
    @StateObject private var viewModel = PublicacionesViewModel()
    @State private var borradorSeleccionado: Borrador?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Vista", selection: $viewModel.modo) {
                        ForEach(ModoPublicaciones.allCases) { modo in
                            Text(modo.rawValue).tag(modo)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                switch viewModel.modo {
                case .borradores:
                    seccionBorradores
                case .publicadas:
                    seccionPublicadas
                case .descartadas:
                    seccionDescartadas
                }
            }
            .listStyle(.insetGrouped)
            .yonkeGroupedBackground()
            .navigationTitle("Publicaciones")
            .toolbar {
                if viewModel.modo == .publicadas {
                    ToolbarItem(placement: .primaryAction) {
                        filtroEstado
                    }
                }
            }
            .navigationDestination(for: Publicacion.self) { publicacion in
                PublicacionDetailView(publicacion: publicacion) {
                    Task { await viewModel.load() }
                }
            }
            .navigationDestination(for: Borrador.self) { borrador in
                BorradorDescartadoView(borrador: borrador) {
                    Task { await viewModel.load() }
                }
            }
            .sheet(item: $borradorSeleccionado, onDismiss: {
                Task { await viewModel.load() }
            }) { borrador in
                BorradorEditorView(borrador: borrador)
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
            .onChange(of: viewModel.estadoFiltro) {
                Task { await viewModel.recargarPublicadas() }
            }
        }
    }

    // MARK: - Secciones

    @ViewBuilder
    private var seccionBorradores: some View {
        if !viewModel.borradores.isEmpty {
            Section {
                ForEach(viewModel.borradores) { borrador in
                    Button {
                        borradorSeleccionado = borrador
                    } label: {
                        BorradorRowView(borrador: borrador)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Edita el precio y las fotos, y luego publícalo.")
            }
        }
    }

    @ViewBuilder
    private var seccionPublicadas: some View {
        if !viewModel.publicaciones.isEmpty {
            Section {
                ForEach(viewModel.publicaciones) { publicacion in
                    NavigationLink(value: publicacion) {
                        PublicacionRowView(publicacion: publicacion)
                    }
                }
            }
        }
    }

    /// Borradores descartados y publicaciones eliminadas. Desde su detalle se pueden restaurar.
    @ViewBuilder
    private var seccionDescartadas: some View {
        if !viewModel.borradoresDescartados.isEmpty {
            Section("Borradores descartados") {
                ForEach(viewModel.borradoresDescartados) { borrador in
                    NavigationLink(value: borrador) {
                        BorradorRowView(borrador: borrador)
                    }
                }
            }
        }
        if !viewModel.publicacionesEliminadas.isEmpty {
            Section("Publicaciones eliminadas") {
                ForEach(viewModel.publicacionesEliminadas) { publicacion in
                    NavigationLink(value: publicacion) {
                        PublicacionRowView(publicacion: publicacion)
                    }
                }
            }
        }
    }

    // MARK: - Filtro

    private var filtroEstado: some View {
        Menu {
            Picker("Estado", selection: $viewModel.estadoFiltro) {
                Text("Todas").tag(EstadoPublicacion?.none)
                ForEach(EstadoPublicacion.filtrables) { estado in
                    Text(estado.label).tag(EstadoPublicacion?.some(estado))
                }
            }
        } label: {
            Label("Filtrar", systemImage: viewModel.estadoFiltro == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }

    // MARK: - Estados vacíos

    @ViewBuilder
    private var contentOverlay: some View {
        let sinDatos = viewModel.borradores.isEmpty && viewModel.publicaciones.isEmpty
            && viewModel.borradoresDescartados.isEmpty && viewModel.publicacionesEliminadas.isEmpty

        if viewModel.isLoading && sinDatos {
            ProgressView("Cargando publicaciones…")
        } else if let error = viewModel.errorMessage, sinDatos {
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Reintentar") {
                    Task { await viewModel.load() }
                }
            }
        } else if viewModel.modo == .borradores && viewModel.borradores.isEmpty {
            ContentUnavailableView(
                "Sin borradores",
                systemImage: "doc.text",
                description: Text("Publica una pieza disponible desde su detalle en Inventario.")
            )
        } else if viewModel.modo == .publicadas && viewModel.publicaciones.isEmpty {
            ContentUnavailableView(
                "Sin publicaciones",
                systemImage: "megaphone",
                description: Text(viewModel.estadoFiltro == nil
                                  ? "Aún no hay piezas publicadas."
                                  : "No hay publicaciones \(viewModel.estadoFiltro?.label.lowercased() ?? "").")
            )
        } else if viewModel.modo == .descartadas
                    && viewModel.borradoresDescartados.isEmpty
                    && viewModel.publicacionesEliminadas.isEmpty {
            ContentUnavailableView(
                "Sin descartadas",
                systemImage: "trash",
                description: Text("Aquí aparecen los borradores descartados y las publicaciones eliminadas.")
            )
        }
    }
}

// MARK: - Filas

struct BorradorRowView: View {
    let borrador: Borrador

    var body: some View {
        HStack(spacing: 12) {
            FotoThumbnail(url: borrador.fotoThumbUrl)

            VStack(alignment: .leading, spacing: 4) {
                Text(borrador.piezaNombre)
                    .font(.headline)
                    .foregroundStyle(YonkeTheme.textPrimary)
                    .lineLimit(2)
                if let vehiculo = borrador.vehiculoTitulo {
                    Text(vehiculo)
                        .font(.caption)
                        .foregroundStyle(YonkeTheme.textSecondary)
                }
            }

            Spacer(minLength: 8)

            TagPill(text: borrador.estado.label, color: borrador.estado.color)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct PublicacionRowView: View {
    let publicacion: Publicacion

    var body: some View {
        HStack(spacing: 12) {
            FotoThumbnail(url: publicacion.fotoThumbUrl)

            VStack(alignment: .leading, spacing: 4) {
                Text(publicacion.titulo)
                    .font(.headline)
                    .foregroundStyle(YonkeTheme.textPrimary)
                    .lineLimit(2)
                Text(publicacion.precio.formatted(.currency(code: "MXN")))
                    .font(.subheadline.bold())
                    .foregroundStyle(YonkeTheme.accentGreen)
                Text("\(publicacion.vistas) vistas")
                    .font(.caption)
                    .foregroundStyle(YonkeTheme.textMuted)
            }

            Spacer(minLength: 8)

            TagPill(text: publicacion.estado.label, color: publicacion.estado.color)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Colores de estado

extension EstadoBorrador {
    var color: Color {
        switch self {
        case .pendiente:         return YonkeTheme.accentYellow
        case .enEdicion:         return YonkeTheme.accentBlue
        case .listoParaPublicar: return YonkeTheme.accentGreen
        case .publicado:         return YonkeTheme.accentPurple
        case .descartado:        return YonkeTheme.accentRed
        }
    }
}

extension EstadoPublicacion {
    var color: Color {
        switch self {
        case .activa:              return YonkeTheme.accentGreen
        case .pausada:             return YonkeTheme.accentOrange
        case .vendida:             return YonkeTheme.accentPurple
        case .eliminada, .expirada: return YonkeTheme.textMuted
        }
    }
}
