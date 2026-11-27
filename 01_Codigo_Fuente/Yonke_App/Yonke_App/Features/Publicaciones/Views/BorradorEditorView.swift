import SwiftUI

// MARK: - BorradorEditorView
/// Hoja para editar un borrador y publicarlo. Título y precio son obligatorios.
/// Las fotos salen de la pieza: se eligen cuáles se publican.

struct BorradorEditorView: View {
    @StateObject private var viewModel: BorradorEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmarDescarte = false

    private let columnas = [GridItem(.adaptive(minimum: 84), spacing: 10)]

    init(borrador: Borrador) {
        _viewModel = StateObject(wrappedValue: BorradorEditorViewModel(borrador: borrador))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Publicación") {
                    TextField("Título", text: $viewModel.titulo, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Descripción", text: $viewModel.descripcion, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Precio y condición") {
                    LabeledContent("Precio (MXN)") {
                        TextField("0.00", text: $viewModel.precioTexto)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Condición", selection: $viewModel.condicion) {
                        Text("Selecciona").tag(CondicionPieza?.none)
                        ForEach(CondicionPieza.allCases) { condicion in
                            Text(condicion.label).tag(CondicionPieza?.some(condicion))
                        }
                    }
                }

                Section {
                    fotosGrid
                } header: {
                    Text("Fotos a publicar")
                } footer: {
                    Text("Se publican las fotos marcadas. Agrega más fotos desde el detalle de la pieza.")
                }

                Section {
                    Button("Guardar borrador") {
                        Task { _ = await viewModel.guardar() }
                    }
                    .disabled(!viewModel.puedeGuardar)

                    Button("Publicar") {
                        Task { await viewModel.publicar() }
                    }
                    .disabled(!viewModel.puedePublicar)
                    .bold()
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(YonkeTheme.accentRed)
                    }
                }
            }
            .yonkeGroupedBackground()
            .navigationTitle("Borrador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Descartar borrador", systemImage: "trash", role: .destructive) {
                            confirmarDescarte = true
                        }
                        .disabled(!viewModel.borrador.estado.estaAbierto)
                    } label: {
                        Label("Más", systemImage: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("¿Descartar este borrador?", isPresented: $confirmarDescarte, titleVisibility: .visible) {
                Button("Descartar", role: .destructive) {
                    Task {
                        if await viewModel.descartar() { dismiss() }
                    }
                }
            } message: {
                Text("La pieza seguirá disponible en el inventario.")
            }
            .task { await viewModel.cargarFotos() }
            .onChange(of: viewModel.publicacion) { _, nueva in
                if nueva != nil { dismiss() }
            }
        }
    }

    // MARK: - Fotos

    @ViewBuilder
    private var fotosGrid: some View {
        if viewModel.fotosPieza.isEmpty {
            Text("La pieza no tiene fotos todavía.")
                .font(.subheadline)
                .foregroundStyle(YonkeTheme.textSecondary)
        } else {
            LazyVGrid(columns: columnas, spacing: 10) {
                ForEach(viewModel.fotosPieza) { foto in
                    fotoCelda(foto)
                }
            }
        }
    }

    private func fotoCelda(_ foto: FotoPieza) -> some View {
        let seleccionada = viewModel.estaSeleccionada(foto.id)
        return Button {
            viewModel.alternarFoto(foto.id)
        } label: {
            FotoThumbnail(url: foto.thumbUrl, size: 84)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: seleccionada ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(seleccionada ? YonkeTheme.accentGreen : YonkeTheme.textMuted)
                        .background(Circle().fill(YonkeTheme.background).padding(2))
                        .padding(4)
                }
                .opacity(seleccionada ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(seleccionada ? "Foto seleccionada" : "Foto no seleccionada")
        .accessibilityAddTraits(seleccionada ? .isSelected : [])
    }
}
