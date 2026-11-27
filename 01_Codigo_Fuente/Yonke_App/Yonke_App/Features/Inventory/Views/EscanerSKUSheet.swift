import SwiftUI
import VisionKit
import Vision

// MARK: - EscanerSKUSheet
/// Lee el código de una pieza con la cámara (VisionKit) y abre su detalle.
/// En simulador o en equipos sin escáner, el SKU se escribe a mano.

struct EscanerSKUSheet: View {
    let onEncontrada: (PiezaInventario) -> Void

    @StateObject private var viewModel = EscanerSKUViewModel()

    private var escanerDisponible: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if escanerDisponible {
                    ZStack(alignment: .bottom) {
                        EscanerCamara { codigo in
                            Task { await buscar(codigo) }
                        }
                        Text("Apunta al código del SKU")
                            .font(.footnote.bold())
                            .foregroundStyle(YonkeTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: .capsule)
                            .padding(.bottom, 12)
                    }
                    .frame(maxHeight: 340)
                    .clipShape(.rect(cornerRadius: 16))
                } else {
                    ContentUnavailableView(
                        "Cámara no disponible",
                        systemImage: "camera.viewfinder",
                        description: Text("Escribe el SKU para buscar la pieza.")
                    )
                    .frame(maxHeight: 220)
                }

                entradaManual

                if viewModel.buscando {
                    ProgressView("Buscando pieza…")
                }

                if let error = viewModel.errorMessage {
                    VStack(spacing: 10) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(YonkeTheme.accentRed)
                            .multilineTextAlignment(.center)
                        Button("Escanear de nuevo") {
                            viewModel.reiniciar()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
            .background(YonkeTheme.background.ignoresSafeArea())
            .navigationTitle("Escanear SKU")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Entrada manual

    private var entradaManual: some View {
        HStack(spacing: 10) {
            TextField("YNQ-…", text: $viewModel.codigoManual)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await buscarManual() }
                }
                .padding(12)
                .yonkeCard(cornerRadius: 10)

            Button("Buscar") {
                Task { await buscarManual() }
            }
            .buttonStyle(.borderedProminent)
            .tint(YonkeTheme.accentRed)
            .disabled(viewModel.codigoManual.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.buscando)
        }
    }

    // MARK: - Búsqueda

    private func buscar(_ codigo: String) async {
        if let pieza = await viewModel.buscar(codigo) {
            onEncontrada(pieza)
        }
    }

    private func buscarManual() async {
        // Una búsqueda manual siempre se intenta, aunque el código ya haya fallado.
        viewModel.reiniciar()
        await buscar(viewModel.codigoManual)
    }
}

// MARK: - EscanerCamara
/// Vista de VisionKit que reporta los códigos de barras y QR que reconoce.

struct EscanerCamara: UIViewControllerRepresentable {
    let onCodigo: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodigo: onCodigo)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.code128, .code39, .ean13, .ean8, .upce, .qr])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onCodigo: (String) -> Void

        init(onCodigo: @escaping (String) -> Void) {
            self.onCodigo = onCodigo
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let codigo) = item, let texto = codigo.payloadStringValue {
                    onCodigo(texto)
                    return
                }
            }
        }
    }
}
