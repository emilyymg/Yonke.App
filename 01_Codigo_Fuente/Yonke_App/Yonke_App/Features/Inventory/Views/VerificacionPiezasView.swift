import SwiftUI

// MARK: - VerificacionRef
/// Identifica la verificación abierta del vehículo recién registrado.

struct VerificacionRef: Identifiable, Hashable {
    let id: String
}

// MARK: - VerificacionPiezasView
/// Recorre las piezas por confirmar del vehículo, una tarjeta a pantalla completa.
/// Deslizar a la izquierda: la pieza no existe en este vehículo.
/// Deslizar a la derecha: la pieza existe y pasa al resumen.

struct VerificacionPiezasView: View {
    @StateObject private var viewModel: VerificacionPiezasViewModel
    @ObservedObject private var cola = FotoUploadQueue.shared
    @Environment(\.dismiss) private var dismiss

    @State private var datos = DatosPiezaTarjeta()
    @State private var desplazamiento: CGFloat = 0
    @State private var mostrarAgregar = false
    @State private var nombreNueva = ""

    private let umbral: CGFloat = 120

    init(vehiculoId: String) {
        _viewModel = StateObject(wrappedValue: VerificacionPiezasViewModel(vehiculoId: vehiculoId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.enResumen {
                    ResumenVerificacionView(viewModel: viewModel) {
                        mostrarAgregar = true
                    }
                } else if let actual = viewModel.actual {
                    recorrido(actual)
                } else {
                    ProgressView("Cargando piezas…")
                }
            }
            .yonkeGroupedBackground()
            .navigationTitle("Verificación de piezas")
            .navigationSubtitle(viewModel.tituloVehiculo ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.actual?.id, initial: true) {
                datos = viewModel.actual.map { DatosPiezaTarjeta(pieza: $0) } ?? DatosPiezaTarjeta()
            }
            .onChange(of: cola.exitosas) {
                if let id = viewModel.actual?.id {
                    Task { await viewModel.recargar(piezaId: id) }
                }
            }
            .alert("Pieza fuera de catálogo", isPresented: $mostrarAgregar) {
                TextField("Nombre de la pieza", text: $nombreNueva)
                Button("Agregar") {
                    let nombre = nombreNueva
                    Task {
                        if await viewModel.agregarPiezaManual(nombre: nombre) {
                            nombreNueva = ""
                        }
                    }
                }
                Button("Cancelar", role: .cancel) { nombreNueva = "" }
            } message: {
                Text("Se crea una tarjeta nueva para revisarla como las demás.")
            }
            .alert("Verificación terminada", isPresented: Binding(
                get: { viewModel.resultadoConfirmacion != nil },
                set: { if !$0 { viewModel.resultadoConfirmacion = nil } }
            )) {
                Button("Listo") { dismiss() }
            } message: {
                Text(mensajeResultado)
            }
        }
    }

    private var mensajeResultado: String {
        guard let resultado = viewModel.resultadoConfirmacion else { return "" }
        var texto = "\(resultado.confirmadas) piezas disponibles."
        if !resultado.pendientes.isEmpty {
            texto += " \(resultado.pendientes.count) quedaron por confirmar porque no tienen precio o condición."
        }
        return texto
    }

    // MARK: - Recorrido

    private func recorrido(_ actual: PiezaInventario) -> some View {
        VStack(spacing: 0) {
            progreso

            TarjetaPieza(pieza: actual, datos: $datos) {
                Task { await viewModel.recargar(piezaId: actual.id) }
            }
                .id(actual.id)
                .offset(x: desplazamiento)
                .rotationEffect(.degrees(Double(desplazamiento / 25)))
                .overlay(alignment: .topLeading) {
                    etiqueta("SÍ EXISTE", color: YonkeTheme.accentGreen)
                        .opacity(Double(max(0, desplazamiento) / umbral))
                }
                .overlay(alignment: .topTrailing) {
                    etiqueta("NO EXISTE", color: YonkeTheme.accentRed)
                        .opacity(Double(max(0, -desplazamiento) / umbral))
                }
                .gesture(arrastre)

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(YonkeTheme.accentRed)
                    .padding(.horizontal)
            }

            botones
        }
    }

    private var progreso: some View {
        VStack(spacing: 6) {
            ProgressView(value: Double(viewModel.revisadas),
                         total: Double(max(viewModel.totalPiezas, 1)))
                .tint(YonkeTheme.accentBlue)
            Text("Pieza \(viewModel.revisadas + 1) de \(viewModel.totalPiezas) · \(viewModel.aceptadas.count) aceptadas, \(viewModel.descartadas) descartadas")
                .font(.caption)
                .foregroundStyle(YonkeTheme.textSecondary)
        }
        .padding()
    }

    private var botones: some View {
        HStack(spacing: 12) {
            Button {
                accion(-1) { await viewModel.descartar() }
            } label: {
                Label("No existe", systemImage: "xmark")
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(YonkeTheme.accentRed)

            Button {
                let copia = datos
                accion(1) { await viewModel.aceptar(datos: copia) }
            } label: {
                Label("Sí existe", systemImage: "checkmark")
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(YonkeTheme.accentGreen)
        }
        .controlSize(.large)
        .padding()
        .disabled(viewModel.isWorking)
    }

    private func etiqueta(_ texto: String, color: Color) -> some View {
        Text(texto)
            .font(.title2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 3))
            .padding(24)
            .allowsHitTesting(false)
    }

    // MARK: - Gestos

    private var arrastre: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { valor in
                guard !viewModel.isWorking, horizontal(valor) else { return }
                desplazamiento = valor.translation.width
            }
            .onEnded { valor in
                guard !viewModel.isWorking else { return }
                let ancho = valor.translation.width
                if horizontal(valor), ancho < -umbral {
                    accion(-1) { await viewModel.descartar() }
                } else if horizontal(valor), ancho > umbral {
                    let copia = datos
                    accion(1) { await viewModel.aceptar(datos: copia) }
                } else {
                    withAnimation(.spring()) { desplazamiento = 0 }
                }
            }
    }

    private func horizontal(_ valor: DragGesture.Value) -> Bool {
        abs(valor.translation.width) > abs(valor.translation.height)
    }

    /// Saca la tarjeta de pantalla, ejecuta la acción y, si falla, la regresa.
    private func accion(_ direccion: CGFloat, _ operacion: @escaping () async -> Void) {
        guard !viewModel.isWorking else { return }
        withAnimation(.easeIn(duration: 0.2)) { desplazamiento = direccion * 700 }
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await operacion()
            desplazamiento = 0
        }
    }
}

// MARK: - TarjetaPieza
/// Tarjeta a pantalla completa de una pieza del catálogo del vehículo.

struct TarjetaPieza: View {
    let pieza: PiezaInventario
    @Binding var datos: DatosPiezaTarjeta
    var onCambio: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pieza.nombre)
                        .font(.title.bold())
                        .foregroundStyle(YonkeTheme.textPrimary)
                    if let sku = pieza.sku {
                        Text(sku)
                            .font(.caption.monospaced())
                            .foregroundStyle(YonkeTheme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Datos")
                        .font(.headline)
                        .foregroundStyle(YonkeTheme.textPrimary)

                    TextField("Descripción", text: $datos.descripcion, axis: .vertical)
                        .lineLimit(2...5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estado de la pieza")
                            .font(.subheadline)
                            .foregroundStyle(YonkeTheme.textSecondary)
                        Picker("Estado de la pieza", selection: $datos.condicion) {
                            Text("Sin especificar").tag(CondicionPieza?.none)
                            ForEach(CondicionPieza.allCases) { condicion in
                                Text(condicion.label).tag(CondicionPieza?.some(condicion))
                            }
                        }
                    }

                    TextField("Precio (MXN)", text: $datos.precioTexto)
                        .keyboardType(.decimalPad)
                }
                .padding(16)
                .yonkeCard(cornerRadius: 12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Fotos")
                        .font(.headline)
                        .foregroundStyle(YonkeTheme.textPrimary)
                    FotosPiezaControles(piezaId: pieza.id, fotos: pieza.fotos, onCambio: onCambio)
                }
                .padding(16)
                .yonkeCard(cornerRadius: 12)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
