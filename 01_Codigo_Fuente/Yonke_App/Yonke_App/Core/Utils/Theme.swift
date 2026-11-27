import SwiftUI
import Combine

// MARK: - YonkeTheme
/// Design tokens shared with the web app (YonkeMain/src/app/globals.css).
/// Same brand palette on both platforms: warm near-black surfaces, warm white
/// text, and the brand red accent. Status colors below are semantic and stay
/// the same across screens.

struct YonkeTheme {

    // MARK: - Background & Surface Colors (shared with web: --ground, --surface, --field, --border-subtle)
    static let background       = Color(hex: "#0A0A0C")
    static let surface          = Color(hex: "#141416")
    static let surfaceElevated  = Color(hex: "#1A1A1D")
    static let cardBorder       = Color(hex: "#252528")

    // MARK: - Accent Colors
    static let accentRed        = Color(hex: "#E53E3E")   // brand red, same as web --accent
    static let accentGreen      = Color(hex: "#48BB78")
    static let accentOrange     = Color(hex: "#ED8936")
    static let accentBlue       = Color(hex: "#4299E1")
    static let accentYellow     = Color(hex: "#ECC94B")
    static let accentPurple     = Color(hex: "#9F7AEA")
    static let accentTeal       = Color(hex: "#38B2AC")

    // MARK: - Text Colors (shared with web: --ink, --ink-secondary)
    // The web has two text levels, so "muted" maps to the secondary tone.
    // #8A8A86 is 5.0:1 on surfaceElevated and 5.7:1 on background (WCAG AA).
    static let textPrimary      = Color(hex: "#EDEDEB")
    static let textSecondary    = Color(hex: "#8A8A86")
    static let textMuted        = textSecondary

    // MARK: - Category Tag Colors
    static func tagColor(for category: String) -> Color {
        switch category.lowercased() {
        case "motor":        return accentOrange
        case "carrocería":   return accentBlue
        case "eléctrico":    return accentYellow
        case "transmisión":  return accentPurple
        case "frenos":       return accentRed
        case "suspensión":   return accentTeal
        case "enfriamiento": return accentBlue
        case "climatización": return accentTeal
        default:             return accentBlue
        }
    }

    // MARK: - Category Icons (SF Symbols)
    static func iconName(for category: String) -> String {
        switch category.lowercased() {
        case "motor":        return "bolt.fill"
        case "carrocería":   return "car.side.fill"
        case "eléctrico":    return "lightbulb.fill"
        case "transmisión":  return "gearshape.2.fill"
        case "frenos":       return "circle.circle.fill"
        case "suspensión":   return "arrow.up.arrow.down"
        case "enfriamiento": return "drop.fill"
        case "climatización": return "snowflake"
        default:             return "wrench.and.screwdriver.fill"
        }
    }

    // MARK: - Condition Badge
    static func conditionColor(_ condition: PartCondition) -> Color {
        switch condition {
        case .excellent: return accentGreen
        case .good:      return accentBlue
        case .fair:      return accentOrange
        case .broken:    return accentRed
        }
    }

    static func conditionLabel(_ condition: PartCondition) -> String {
        switch condition {
        case .excellent: return "Excelente"
        case .good:      return "Bueno"
        case .fair:      return "Regular"
        case .broken:    return "Dañado"
        }
    }

    // MARK: - Vehicle Status
    static func statusColor(_ status: VehicleStatus) -> Color {
        switch status {
        case .received:   return accentYellow
        case .processing: return accentOrange
        case .dismantled: return accentGreen
        }
    }

    static func statusLabel(_ status: VehicleStatus) -> String {
        switch status {
        case .received:   return "Recibido"
        case .processing: return "En Proceso"
        case .dismantled: return "Desmantelado"
        }
    }

    // MARK: - Draft Status
    static func draftStatusColor(_ status: DraftStatus) -> Color {
        switch status {
        case .listo:     return accentGreen
        case .pendiente: return accentYellow
        case .vacio:     return accentRed
        }
    }

    // MARK: - Price Formatter
    static func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))") + " MXN"
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}
