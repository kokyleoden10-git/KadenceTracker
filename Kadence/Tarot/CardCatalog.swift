import Foundation

/// v3 spec, §Resonance — the full 78-card attribution table, transcribed
/// directly from the spec's tables. This is what makes card→sign/planet
/// lookups possible without an ephemeris: none of this needs current
/// planetary positions, it's a fixed correspondence table.
enum ZodiacSign: String, CaseIterable, Codable, Identifiable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum Planet: String, CaseIterable, Codable, Identifiable {
    case sun, moon, mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum Element: String, CaseIterable, Codable {
    case fire, water, air, earth
    var displayName: String { rawValue.capitalized }
}

enum Suit: String, CaseIterable, Codable {
    case wands, cups, swords, pentacles
    var element: Element {
        switch self {
        case .wands: return .fire
        case .cups: return .water
        case .swords: return .air
        case .pentacles: return .earth
        }
    }
}

/// Traditional (not modern) rulerships — matches the decan-ruler table's
/// own use of only the 7 classical planets, so chart-ruler lookups stay
/// consistent with decan lookups.
let traditionalRuler: [ZodiacSign: Planet] = [
    .aries: .mars, .taurus: .venus, .gemini: .mercury, .cancer: .moon,
    .leo: .sun, .virgo: .mercury, .libra: .venus, .scorpio: .mars,
    .sagittarius: .jupiter, .capricorn: .saturn, .aquarius: .saturn, .pisces: .jupiter,
]

/// Chaldean-order decan rulers, 1st/2nd/3rd, per sign.
private let decanRulers: [ZodiacSign: [Planet]] = [
    .aries: [.mars, .sun, .venus],
    .taurus: [.mercury, .moon, .saturn],
    .gemini: [.jupiter, .mars, .sun],
    .cancer: [.venus, .mercury, .moon],
    .leo: [.saturn, .jupiter, .mars],
    .virgo: [.sun, .venus, .mercury],
    .libra: [.moon, .saturn, .jupiter],
    .scorpio: [.mars, .sun, .venus],
    .sagittarius: [.mercury, .moon, .saturn],
    .capricorn: [.jupiter, .mars, .sun],
    .aquarius: [.venus, .mercury, .moon],
    .pisces: [.saturn, .jupiter, .mars],
]

/// Which sign a suit's 2-4 / 5-7 / 8-10 group falls in.
private let suitDecanSigns: [Suit: [ZodiacSign]] = [
    .wands: [.aries, .leo, .sagittarius],
    .cups: [.cancer, .scorpio, .pisces],
    .swords: [.libra, .aquarius, .gemini],
    .pentacles: [.capricorn, .taurus, .virgo],
]

enum Rank: String, CaseIterable, Codable {
    case knight, queen, prince, princess

    /// Thoth uses the canonical names already. RWS and Marseille share the
    /// same King/Queen/Knight/Page naming — a Thoth Knight is an RWS King,
    /// and an RWS Knight is a Thoth Prince. Getting this wrong makes every
    /// court resonance off by one rank.
    func displayName(for tradition: Tradition) -> String {
        switch tradition {
        case .thoth, .other:
            return rawValue.capitalized
        case .rws, .marseille:
            switch self {
            case .knight: return "King"
            case .queen: return "Queen"
            case .prince: return "Knight"
            case .princess: return "Page"
            }
        }
    }
}

struct TarotCard: Identifiable, Hashable {
    let id: String
    let displayName: String
    let signs: [ZodiacSign]
    let planets: [Planet]
    let element: Element?
    let rank: Rank?
    let suit: Suit?

    func name(for tradition: Tradition) -> String {
        guard let rank, let suit else { return displayName }
        return "\(rank.displayName(for: tradition)) of \(suit.rawValue.capitalized)"
    }
}

enum CardCatalog {
    static let majorArcana: [TarotCard] = [
        TarotCard(id: "major-00", displayName: "The Fool", signs: [], planets: [.uranus], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-01", displayName: "The Magician", signs: [], planets: [.mercury], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-02", displayName: "The High Priestess", signs: [], planets: [.moon], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-03", displayName: "The Empress", signs: [], planets: [.venus], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-04", displayName: "The Emperor", signs: [.aries], planets: [.mars], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-05", displayName: "The Hierophant", signs: [.taurus], planets: [.venus], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-06", displayName: "The Lovers", signs: [.gemini], planets: [.mercury], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-07", displayName: "The Chariot", signs: [.cancer], planets: [.moon], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-08", displayName: "Strength", signs: [.leo], planets: [.sun], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-09", displayName: "The Hermit", signs: [.virgo], planets: [.mercury], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-10", displayName: "Wheel of Fortune", signs: [], planets: [.jupiter], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-11", displayName: "Justice", signs: [.libra], planets: [.venus], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-12", displayName: "The Hanged Man", signs: [], planets: [.neptune], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-13", displayName: "Death", signs: [.scorpio], planets: [.mars, .pluto], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-14", displayName: "Temperance", signs: [.sagittarius], planets: [.jupiter], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-15", displayName: "The Devil", signs: [.capricorn], planets: [.saturn], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-16", displayName: "The Tower", signs: [], planets: [.mars], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-17", displayName: "The Star", signs: [.aquarius], planets: [.saturn, .uranus], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-18", displayName: "The Moon", signs: [.pisces], planets: [.jupiter, .neptune], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-19", displayName: "The Sun", signs: [], planets: [.sun], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-20", displayName: "Judgement", signs: [], planets: [.pluto], element: nil, rank: nil, suit: nil),
        TarotCard(id: "major-21", displayName: "The World", signs: [], planets: [.saturn], element: nil, rank: nil, suit: nil),
    ]

    static let aces: [TarotCard] = Suit.allCases.map { suit in
        TarotCard(id: "\(suit.rawValue)-01", displayName: "Ace of \(suit.rawValue.capitalized)", signs: [], planets: [], element: suit.element, rank: nil, suit: suit)
    }

    static let minors: [TarotCard] = Suit.allCases.flatMap { suit -> [TarotCard] in
        (2...10).map { number in
            let groupIndex = (number - 2) / 3
            let decanIndex = (number - 2) % 3
            let sign = suitDecanSigns[suit]![groupIndex]
            let planet = decanRulers[sign]![decanIndex]
            return TarotCard(
                id: "\(suit.rawValue)-\(String(format: "%02d", number))",
                displayName: "\(number) of \(suit.rawValue.capitalized)",
                signs: [sign],
                planets: [planet],
                element: suit.element,
                rank: nil,
                suit: suit
            )
        }
    }

    /// Spans cross two signs; without exact natal degrees (only signs are
    /// captured), resonance checks membership in either sign of the span
    /// rather than resolving which side of the 20° cusp a body falls on.
    static let courts: [TarotCard] = [
        TarotCard(id: "court-knight-wands", displayName: "Knight of Wands", signs: [.scorpio, .sagittarius], planets: [.mars, .jupiter], element: .fire, rank: .knight, suit: .wands),
        TarotCard(id: "court-knight-cups", displayName: "Knight of Cups", signs: [.aquarius, .pisces], planets: [.saturn, .jupiter], element: .fire, rank: .knight, suit: .cups),
        TarotCard(id: "court-knight-swords", displayName: "Knight of Swords", signs: [.taurus, .gemini], planets: [.venus, .mercury], element: .fire, rank: .knight, suit: .swords),
        TarotCard(id: "court-knight-pentacles", displayName: "Knight of Pentacles", signs: [.leo, .virgo], planets: [.sun, .mercury], element: .fire, rank: .knight, suit: .pentacles),
        TarotCard(id: "court-queen-wands", displayName: "Queen of Wands", signs: [.pisces, .aries], planets: [.jupiter, .mars], element: .water, rank: .queen, suit: .wands),
        TarotCard(id: "court-queen-cups", displayName: "Queen of Cups", signs: [.gemini, .cancer], planets: [.mercury, .moon], element: .water, rank: .queen, suit: .cups),
        TarotCard(id: "court-queen-swords", displayName: "Queen of Swords", signs: [.virgo, .libra], planets: [.mercury, .venus], element: .water, rank: .queen, suit: .swords),
        TarotCard(id: "court-queen-pentacles", displayName: "Queen of Pentacles", signs: [.sagittarius, .capricorn], planets: [.jupiter, .saturn], element: .water, rank: .queen, suit: .pentacles),
        TarotCard(id: "court-prince-wands", displayName: "Prince of Wands", signs: [.cancer, .leo], planets: [.moon, .sun], element: .air, rank: .prince, suit: .wands),
        TarotCard(id: "court-prince-cups", displayName: "Prince of Cups", signs: [.libra, .scorpio], planets: [.venus, .mars], element: .air, rank: .prince, suit: .cups),
        TarotCard(id: "court-prince-swords", displayName: "Prince of Swords", signs: [.capricorn, .aquarius], planets: [.saturn], element: .air, rank: .prince, suit: .swords),
        TarotCard(id: "court-prince-pentacles", displayName: "Prince of Pentacles", signs: [.aries, .taurus], planets: [.mars, .venus], element: .air, rank: .prince, suit: .pentacles),
        TarotCard(id: "court-princess-wands", displayName: "Princess of Wands", signs: [.cancer, .leo, .virgo], planets: [], element: .earth, rank: .princess, suit: .wands),
        TarotCard(id: "court-princess-cups", displayName: "Princess of Cups", signs: [.libra, .scorpio, .sagittarius], planets: [], element: .earth, rank: .princess, suit: .cups),
        TarotCard(id: "court-princess-swords", displayName: "Princess of Swords", signs: [.capricorn, .aquarius, .pisces], planets: [], element: .earth, rank: .princess, suit: .swords),
        TarotCard(id: "court-princess-pentacles", displayName: "Princess of Pentacles", signs: [.aries, .taurus, .gemini], planets: [], element: .earth, rank: .princess, suit: .pentacles),
    ]

    static let all: [TarotCard] = majorArcana + aces + minors + courts

    static func card(id: String) -> TarotCard? {
        all.first { $0.id == id }
    }
}
