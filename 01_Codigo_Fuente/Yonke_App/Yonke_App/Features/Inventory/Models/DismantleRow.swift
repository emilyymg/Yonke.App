import Foundation

// MARK: - DismantleRow
/// One selectable part in the dismantling checklist.

struct DismantleRow: Identifiable {
    let id = UUID()
    var name: String
    var category: String
    var condition: PartCondition
    var price: Double
    var isSelected: Bool

    static func defaultChecklist() -> [DismantleRow] {
        [
            // Motor
            DismantleRow(name: "Motor Completo",       category: "Motor",       condition: .good, price: 1500, isSelected: false),
            DismantleRow(name: "Alternador",            category: "Motor",       condition: .good, price: 120,  isSelected: false),
            DismantleRow(name: "Motor de Arranque",     category: "Motor",       condition: .good, price: 200,  isSelected: false),
            DismantleRow(name: "Radiador",              category: "Motor",       condition: .good, price: 180,  isSelected: false),
            DismantleRow(name: "Compresor A/C",         category: "Motor",       condition: .good, price: 350,  isSelected: false),

            // Carrocería
            DismantleRow(name: "Puerta Delantera Der.", category: "Carrocería",  condition: .good, price: 250,  isSelected: false),
            DismantleRow(name: "Puerta Delantera Izq.", category: "Carrocería",  condition: .good, price: 250,  isSelected: false),
            DismantleRow(name: "Cofre / Capó",          category: "Carrocería",  condition: .good, price: 300,  isSelected: false),
            DismantleRow(name: "Cajuela / Tapa",        category: "Carrocería",  condition: .good, price: 200,  isSelected: false),
            DismantleRow(name: "Defensa Delantera",     category: "Carrocería",  condition: .good, price: 350,  isSelected: false),

            // Eléctrico
            DismantleRow(name: "Faro Delantero Der.",   category: "Eléctrico",   condition: .good, price: 80,   isSelected: false),
            DismantleRow(name: "Faro Delantero Izq.",   category: "Eléctrico",   condition: .good, price: 80,   isSelected: false),
            DismantleRow(name: "Calavera Trasera Der.", category: "Eléctrico",   condition: .good, price: 60,   isSelected: false),
            DismantleRow(name: "Tablero / Cluster",     category: "Eléctrico",   condition: .good, price: 400,  isSelected: false),

            // Transmisión
            DismantleRow(name: "Transmisión Completa",  category: "Transmisión", condition: .good, price: 800,  isSelected: false),
            DismantleRow(name: "Diferencial",           category: "Transmisión", condition: .good, price: 310,  isSelected: false)
        ]
    }
}
