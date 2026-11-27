import SwiftUI
import PhotosUI
import UIKit

// MARK: - FotosPiezaControles
/// Agregar fotos a una pieza (galería o cámara), ver las miniaturas y quitar las que sobren.
/// Las fotos ya subidas vienen de `fotos`; las que siguen en cola salen de `FotoUploadQueue`.
/// Sin tarjeta propia: se usa dentro de una `Section` o de una tarjeta.

struct FotosPiezaControles: View {
    let piezaId: String
    /// Fotos ya guardadas en la base (derivado `thumb`).
    let fotos: [FotoPieza]
    /// Se llama después de quitar una foto subida, para que el dueño relea la pieza.
    var onCambio: () -> Void = {}

    @ObservedObject private var cola = FotoUploadQueue.shared
    @State private var seleccion: [PhotosPickerItem] = []
    @State private var importando = false
    @State private var mostrarCamara = false
    @State private var fotoAEliminar: String?
    @State private var eliminando = false
    @State private var errorMessage: String?

    private let service: FotoServiceProtocol

    init(piezaId: String,
         fotos: [FotoPieza],
         onCambio: @escaping () -> Void = {},
         service: FotoServiceProtocol = RemoteFotoService.shared) {
        self.piezaId = piezaId
        self.fotos = fotos
        self.onCambio = onCambio
        self.service = service
    }

    private var subidas: [SubidaPendiente] {
        cola.subidas.filter { $0.piezaId == piezaId }
    }

    private var fotosOrdenadas: [FotoPieza] {
        fotos.sorted { $0.orden < $1.orden }
    }

    private var camaraDisponible: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $seleccion, maxSelectionCount: 10, matching: .images) {
                    Label("Galería", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if camaraDisponible {
                    Button {
                        mostrarCamara = true
                    } label: {
                        Label("Cámara", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)

            if importando {
                ProgressView("Preparando fotos…")
            }

            if !fotosOrdenadas.isEmpty || !subidas.isEmpty {
                miniaturas
            }

            ForEach(subidas.filter { $0.estado == .fallido }) { subida in
                filaFallida(subida)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(YonkeTheme.accentRed)
            }
        }
        .onChange(of: seleccion) {
            Task { await importar(seleccion) }
        }
        .fullScreenCover(isPresented: $mostrarCamara) {
            CamaraPicker(
                onCapturar: { imagen in
                    mostrarCamara = false
                    encolar(imagen)
                },
                onCancelar: { mostrarCamara = false }
            )
            .ignoresSafeArea()
        }
        .confirmationDialog("¿Eliminar esta foto?", isPresented: Binding(
            get: { fotoAEliminar != nil },
            set: { if !$0 { fotoAEliminar = nil } }
        ), titleVisibility: .visible) {
            Button("Eliminar foto", role: .destructive) {
                if let id = fotoAEliminar { eliminar(id) }
                fotoAEliminar = nil
            }
        } message: {
            Text("Se quita de la pieza y de sus borradores.")
        }
    }

    // MARK: - Miniaturas

    private var miniaturas: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(fotosOrdenadas) { foto in
                    miniatura {
                        AsyncImage(url: foto.thumbUrl) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                YonkeTheme.surfaceElevated
                            }
                        }
                    } onQuitar: {
                        fotoAEliminar = foto.id
                    }
                    .disabled(eliminando)
                }

                ForEach(subidas) { subida in
                    miniatura {
                        imagenLocal(subida)
                            .overlay { estadoSubida(subida) }
                    } onQuitar: {
                        cola.descartar(subida.id)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.trailing, 10)
            .padding(.bottom, 4)
        }
    }

    /// Contenedor cuadrado con una X en la esquina superior derecha.
    private func miniatura<Contenido: View>(
        @ViewBuilder _ contenido: () -> Contenido,
        onQuitar: @escaping () -> Void
    ) -> some View {
        contenido()
            .frame(width: 64, height: 64)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                Button(action: onQuitar) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.black.opacity(0.7))
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .accessibilityLabel("Quitar foto")
            }
    }

    @ViewBuilder
    private func imagenLocal(_ subida: SubidaPendiente) -> some View {
        if let imagen = UIImage(contentsOfFile: cola.archivoURL(de: subida).path) {
            Image(uiImage: imagen)
                .resizable()
                .scaledToFill()
        } else {
            YonkeTheme.surfaceElevated
        }
    }

    /// Indica que la foto aún no está en el servidor.
    @ViewBuilder
    private func estadoSubida(_ subida: SubidaPendiente) -> some View {
        switch subida.estado {
        case .pendiente, .subiendo:
            ZStack {
                Color.black.opacity(0.45)
                ProgressView()
                    .tint(.white)
            }
        case .fallido:
            ZStack {
                Color.black.opacity(0.55)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(YonkeTheme.accentRed)
            }
        }
    }

    // MARK: - Acciones

    private func importar(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        importando = true
        defer {
            importando = false
            seleccion = []
        }

        for item in items {
            guard let datos = try? await item.loadTransferable(type: Data.self),
                  let imagen = UIImage(data: datos) else { continue }
            encolar(imagen)
        }
    }

    private func encolar(_ imagen: UIImage) {
        guard let jpeg = ImagenJPEG.datos(desde: imagen) else { return }
        cola.agregar(datos: jpeg, piezaId: piezaId)
    }

    private func eliminar(_ fotoId: String) {
        guard !eliminando else { return }
        eliminando = true
        errorMessage = nil
        Task {
            defer { eliminando = false }
            do {
                try await service.eliminarFoto(id: fotoId)
                onCambio()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo eliminar la foto."
            }
        }
    }

    // MARK: - Subidas fallidas

    private func filaFallida(_ subida: SubidaPendiente) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(YonkeTheme.accentRed)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("No se pudo subir una foto")
                    .font(.subheadline)
                    .foregroundStyle(YonkeTheme.textPrimary)
                if let error = subida.ultimoError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(YonkeTheme.textMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Button("Reintentar") {
                cola.reintentar(subida.id)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
