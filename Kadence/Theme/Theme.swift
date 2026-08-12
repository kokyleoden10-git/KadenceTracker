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

/// Astrology-derived palette (spec §10). Domain and font choices are all
/// driven from here so there's one place to retune the theme.
///
/// DM Serif Display (headers/display) + Inter (body/UI) — bundled under
/// Kadence/Resources/Fonts/, registered in project.yml's UIAppFonts.
/// DM Serif Display only ships a Regular weight (no true bold face), so
/// don't apply .fontWeight() on top of displayFont — it'll synthetically
/// (faux-)bold rather than use a real bold glyph set. Use bodyFontSemibold
/// for emphasis on body text instead of .fontWeight(.semibold)/.bold() on
/// top of bodyFont, for the same reason.
enum KadenceTheme {
    static let bg = Color(hex: "12181A")
    static let surface = Color(hex: "1B2427")
    static let textPrimary = Color(hex: "EDE7DD")
    static let textMuted = Color(hex: "8FA39E")

    static let piscesTeal = Color(hex: "3E8E85")        // primary accent, Wellbeing
    static let piscesSeafoam = Color(hex: "7FBFB0")     // hover/secondary states, tag chips
    static let aquariusIce = Color(hex: "5FA8D3")       // nav/chrome, Knowledge
    static let capricornBronze = Color(hex: "B08355")   // Systems
    static let sagittariusIndigo = Color(hex: "6B5B95") // Creativity, Reflection accent
    static let ariesEmber = Color(hex: "C0604A")        // streak indicator only

    static func color(for domain: Domain) -> Color {
        switch domain {
        case .wellbeing: return piscesTeal
        case .knowledge: return aquariusIce
        case .creativity: return sagittariusIndigo
        case .systems: return capricornBronze
        }
    }

    static func displayFont(_ size: CGFloat) -> Font {
        .custom("DMSerifDisplay-Regular", size: size)
    }

    static func bodyFont(_ size: CGFloat = 16) -> Font {
        .custom("Inter-Regular", size: size)
    }

    static func bodyFontSemibold(_ size: CGFloat = 16) -> Font {
        .custom("Inter-SemiBold", size: size)
    }

    /// Shared across every tab's header (Today, Draw, Tides) so the
    /// personalized-title pattern — "{nickname}'s {screen}", falling back
    /// to just the screen name — stays identical everywhere instead of
    /// three separately-drifting implementations.
    static func personalizedTitle(nickname: String?, screen: String) -> String {
        if let nickname, !nickname.isEmpty {
            return "\(nickname)'s \(screen)"
        }
        return screen
    }
}
