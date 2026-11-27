import SwiftUI

// MARK: - PiezaDetailView
/// Detalle de la pieza: galería (derivado `medium`), datos y acciones según el estado.
/// Publicar, vender y devolver llegan en las fases 5 y 6.

struct PiezaDetailView: View {
    let vehiculo: VehiculoInventario?

    @StateObject private var viewModel: PiezaDetailViewModel
    @ObservedObject private var cola = FotoUploadQueue.shared
    @State private var mostrarConfirmar = false
    @State private var mostrarDescartar = false
    @State private var mostrarVender = false
    @State private var mostrarDevolver = false

    init(pieza: PiezaInventario,
         vehiculo: VehiculoInventario?,
         onCambio: @escaping (PiezaInventario) -> Void = { _ in }) {
        self.vehiculo = vehiculo
        _viewModel = StateObject(wrappedValue: PiezaDetailViewModel(pieza: pieza, onCambio: onCambio))
    }

    private var pieza: PiezaInventario { viewModel.pieza }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                galeria
                fotosCard
                encabezado
                acciones
                datos
                if let descripcion = pieza.descripcion, !descripcion.isEmpty {
                    descripcionCard(descripcion)
                }
            }
            .padding()
        }
        .background(YonkeTheme.background.ignoresSafeArea())
        .navigationTitle(pieza.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $mostrarConfirmar) {
            ConfirmarPiezaSheet(
                pieza: pieza,
                onFotosCambiadas: { Task { await viewModel.refrescar() } },
                onConfirmada: { actualizada in viewModel.aplicar(actualizada) }
            )
        }
        .sheet(item: $viewModel.borradorEnEdicion) { borrador in
            BorradorEditorView(borrador: borrador)
        }
        .sheet(isPresented: $mostrarVender) {
            VenderPiezaSheet(pieza: pieza) { _ in
                Task { await viewModel.refrescar() }
            }
        }
        .sheet(item: $viewModel.ventaEnDetalle) { venta in
            NavigationStack {
                VentaDetailView(venta: venta) {
                    Task { await viewModel.refrescar() }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { viewModel.ventaEnDetalle = nil }
                    }
                }
            }
        }
        .confirmationDialog("¿Descartar esta pieza?", isPresented: $mostrarDescartar, titleVisibility: .visible) {
            Button("Descartar", role: .destructive) {
                Task { await viewModel.ejecutar(.descartar) }
            }
        } message: {
            Text("La pieza dejará de aparecer en el inventario disponible.")
        }
        .confirmationDialog("¿Devolver la venta?", isPresented: $mostrarDevolver, titleVisibility: .visible) {
            Button("Devolver venta", role: .destructive) {
                Task { await viewModel.devolverVenta() }
            }
        } message: {
            Text("La pieza volverá a estar disponible en el inventario.")
        }
        .onChange(of: cola.exitosas) {
            Task { await viewModel.refrescar() }
        }
    }

    // MARK: - Fotos

    private var fotosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agregar fotos")
                .font(.headline)
                .foregroundStyle(YonkeTheme.textPrimary)
            FotosPiezaControles(piezaId: pieza.id, fotos: pieza.fotos) {
                Task { await viewModel.refrescar() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .yonkeCard(cornerRadius: 12)
    }

    // MARK: - Galería

    @ViewBuilder
    private var galeria: some View {
        if pieza.fotos.isEmpty {
            ZStack {
                YonkeTheme.surface
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("Sin fotos")
                        .font(.subheadline)
                }
                .foregroundStyle(YonkeTheme.textMuted)
            }
            .frame(height: 240)
            .clipShape(.rect(cornerRadius: 16))
            .accessibilityLabel("Sin fotos")
        } else {
            TabView {
                ForEach(pieza.fotos.sorted(by: { $0.orden < $1.orden })) { foto in
                    AsyncImage(url: foto.mediumUrl) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            YonkeTheme.surface
                                .overlay { ProgressView() }
                        }
                    }
                    .clipShape(.rect(cornerRadius: 16))
                    .padding(.horizontal, 4)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: pieza.fotos.count > 1 ? .always : .never))
            .frame(height: 260)
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(pieza.nombre)
                    .font(.title2.bold())
                    .foregroundStyle(YonkeTheme.textPrimary)
                Spacer(minLength: 8)
                TagPill(text: pieza.estado.label, color: pieza.estado.color)
            }

            if let precio = pieza.precioVenta {
                Text(precio.formatted(.currency(code: "MXN")))
                    .font(.title3.bold())
                    .foregroundStyle(YonkeTheme.accentGreen)
            } else {
                Text("Sin precio")
                    .font(.subheadline)
                    .foregroundStyle(YonkeTheme.textMuted)
            }
        }
    }

    // MARK: - Acciones

    @ViewBuilder
    private var acciones: some View {
        let disponibles = pieza.estado.accionesDisponibles
        if !disponibles.isEmpty {
            VStack(spacing: 10) {
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(YonkeTheme.accentRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(disponibles) { accion in
                    botonAccion(accion)
                }
            }
        }
    }

    @ViewBuilder
    private func botonAccion(_ accion: AccionPieza) -> some View {
        let etiqueta = Label(accion.titulo, systemImage: accion.icono)
            .font(.headline)
            .frame(maxWidth: .infinity)

        switch accion {
        case .confirmar:
            Button { mostrarConfirmar = true } label: { etiqueta }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(YonkeTheme.accentGreen)
                .disabled(viewModel.isWorking)
        case .publicar:
            Button { Task { await viewModel.iniciarPublicacion() } } label: { etiqueta }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(YonkeTheme.accentRed)
                .disabled(viewModel.isWorking)
        case .vender:
            Button { mostrarVender = true } label: { etiqueta }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(YonkeTheme.accentPurple)
                .disabled(viewModel.isWorking)
        case .verVenta:
            Button { Task { await viewModel.abrirVenta() } } label: { etiqueta }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(YonkeTheme.accentPurple)
                .disabled(viewModel.isWorking)
        case .devolver:
            Button(role: .destructive) { mostrarDevolver = true } label: { etiqueta }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.isWorking)
        case .descartar:
            Button(role: .destructive) { mostrarDescartar = true } label: { etiqueta }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.isWorking)
        case .reservar, .liberar:
            Button { Task { await viewModel.ejecutar(accion) } } label: { etiqueta }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(YonkeTheme.accentOrange)
                .disabled(viewModel.isWorking)
        }
    }

    // MARK: - Datos

    private var datos: some View {
        VStack(spacing: 0) {
            fila("SKU", valor: pieza.sku ?? "Sin SKU", monospaced: true)
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Vehículo", valor: vehiculo?.titulo ?? "Desconocido")
            if let vin = vehiculo?.vin {
                Divider().overlay(YonkeTheme.cardBorder)
                fila("VIN", valor: vin, monospaced: true)
            }
            Divider().overlay(YonkeTheme.cardBorder)
            fila("Condición", valor: pieza.condicion?.label ?? "Sin especificar")
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

    // MARK: - Descripción

    private func descripcionCard(_ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descripción")
                .font(.headline)
                .foregroundStyle(YonkeTheme.textPrimary)
            Text(texto)
                .font(.body)
                .foregroundStyle(YonkeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .yonkeCard(cornerRadius: 12)
    }
}
