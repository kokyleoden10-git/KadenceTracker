import SwiftUI

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}

/// Carried over from the v1 web app's palette (see docs/ for the old repo notes).
/// v1 didn't bundle the DM Serif Display / Inter font files, so this uses system
/// fonts for now — drop the .ttf files into the project and swap Font.custom in
/// here if you want the exact v1 typography.
enum KadenceTheme {
    static let background = Color(hex: "0F1117")
    static let text = Color(hex: "F0EDE6")

    static let sage = Color(hex: "7DB5A0")    // Wellbeing
    static let amber = Color(hex: "C8964E")   // Knowledge
    static let pink = Color(hex: "C47BA0")    // Creativity
    static let purple = Color(hex: "8B77B8")  // Systems

    static func color(for domain: Domain) -> Color {
        switch domain {
        case .wellbeing: return sage
        case .knowledge: return amber
        case .creativity: return pink
        case .systems: return purple
        }
    }

    static func displayFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func bodyFont(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
}
