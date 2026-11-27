import Foundation
import Combine

// MARK: - VentasViewModel
/// Historial de ventas con totales del día o del mes. Solo cuentan las ventas completadas.

enum PeriodoVentas: String, CaseIterable, Identifiable {
    case dia = "Hoy"
    case mes = "Este mes"

    var id: String { rawValue }
}

@MainActor
final class VentasViewModel: ObservableObject {

    @Published var periodo: PeriodoVentas = .dia
    @Published private(set) var ventas: [Venta] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: VentaServiceProtocol

    init(service: VentaServiceProtocol = RemoteVentaService.shared) {
        self.service = service
    }

    /// Ventas del periodo, de la más reciente a la más antigua. Incluye devueltas.
    var ventasDelPeriodo: [Venta] {
        ventas.filter { pertenece($0.fechaVenta) }
    }

    var cantidadCompletadas: Int {
        ventasDelPeriodo.filter { $0.estado == .completada }.count
    }

    var totalIngresos: Double {
        ventasDelPeriodo
            .filter { $0.estado == .completada }
            .reduce(0) { $0 + $1.precioFinal }
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            ventas = try await service.fetchVentas()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar las ventas."
        }
    }

    /// Devuelve la venta. Devuelve true si se completó.
    func devolver(_ venta: Venta) async -> Bool {
        do {
            _ = try await service.devolverVenta(id: venta.id)
            await load()
            return errorMessage == nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo devolver la venta."
            return false
        }
    }

    private func pertenece(_ fecha: Date) -> Bool {
        let calendario = Calendar.current
        switch periodo {
        case .dia:
            return calendario.isDateInToday(fecha)
        case .mes:
            let hoy = Date()
            return calendario.component(.month, from: fecha) == calendario.component(.month, from: hoy)
                && calendario.component(.year, from: fecha) == calendario.component(.year, from: hoy)
        }
    }
}
