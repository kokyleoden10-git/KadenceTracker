import Foundation

/// v3 spec, §Resonance. Runs entirely off sign-level natal data + the
/// static card catalog — no ephemeris, no transits (those need Step 4's
/// frozen sky, which doesn't exist yet, so the "frozen transit" output
/// case never fires here; the other three do).
enum ResonanceTier: String {
    case quiet, active, loud
}

struct ResonanceResult {
    let tier: ResonanceTier
    let note: String?
}

private enum NatalPoint: CaseIterable {
    case sun, moon, mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto, ascendant, midheaven

    var weight: Int {
        switch self {
        case .sun, .moon, .ascendant: return 3
        case .midheaven: return 2
        case .mercury, .venus, .mars, .jupiter, .saturn: return 2
        case .uranus, .neptune, .pluto: return 1
        }
    }

    var planet: Planet? {
        switch self {
        case .sun: return .sun
        case .moon: return .moon
        case .mercury: return .mercury
        case .venus: return .venus
        case .mars: return .mars
        case .jupiter: return .jupiter
        case .saturn: return .saturn
        case .uranus: return .uranus
        case .neptune: return .neptune
        case .pluto: return .pluto
        case .ascendant, .midheaven: return nil
        }
    }

    func sign(in chart: NatalChart) -> ZodiacSign {
        switch self {
        case .sun: return chart.sun
        case .moon: return chart.moon
        case .mercury: return chart.mercury
        case .venus: return chart.venus
        case .mars: return chart.mars
        case .jupiter: return chart.jupiter
        case .saturn: return chart.saturn
        case .uranus: return chart.uranus
        case .neptune: return chart.neptune
        case .pluto: return chart.pluto
        case .ascendant: return chart.ascendant
        case .midheaven: return chart.midheaven
        }
    }

    var displayName: String {
        switch self {
        case .ascendant: return "Ascendant"
        case .midheaven: return "Midheaven"
        case .sun: return "Sun"
        case .moon: return "Moon"
        case .mercury: return "Mercury"
        case .venus: return "Venus"
        case .mars: return "Mars"
        case .jupiter: return "Jupiter"
        case .saturn: return "Saturn"
        case .uranus: return "Uranus"
        case .neptune: return "Neptune"
        case .pluto: return "Pluto"
        }
    }
}

enum ResonanceEngine {
    private static let angularHouses = [1, 4, 7, 10]

    static func resonance(for card: TarotCard, deckTradition: Tradition, chart: NatalChart) -> ResonanceResult {
        let name = card.name(for: deckTradition)
        var score = 0
        var pointsInSign: [String] = []

        for point in NatalPoint.allCases {
            if card.signs.contains(point.sign(in: chart)) {
                score += point.weight
                pointsInSign.append(point.displayName)
            }
        }

        let chartRuler = traditionalRuler[chart.ascendant]
        var rulerMatch: Planet?
        for planet in card.planets {
            if planet == chartRuler {
                score += 2
                rulerMatch = planet
            }
            if let point = NatalPoint.allCases.first(where: { $0.planet == planet }),
               let house = chart.house(of: point.sign(in: chart)), angularHouses.contains(house) {
                score += 1
            }
        }

        var emptyAngularHouse: Int?
        for sign in card.signs {
            if let house = chart.house(of: sign), angularHouses.contains(house) {
                score += 1
                if pointsInSign.isEmpty { emptyAngularHouse = house }
            }
        }

        let tier: ResonanceTier
        switch score {
        case 0...1: tier = .quiet
        case 2...4: tier = .active
        default: tier = .loud
        }

        let note = noteText(
            cardName: name, signName: card.signs.first?.displayName,
            pointsInSign: pointsInSign, rulerMatch: rulerMatch,
            ascendantSign: chart.ascendant.displayName, emptyAngularHouse: emptyAngularHouse
        )
        return ResonanceResult(tier: tier, note: note)
    }

    /// "Silence is a feature" — only three of the spec's four cases can
    /// fire without transit data, and even those don't fire on every draw
    /// (e.g. the empty-sign case only speaks up when that sign sits in an
    /// angular house, same as the spec's own worked example).
    private static func noteText(
        cardName: String, signName: String?, pointsInSign: [String],
        rulerMatch: Planet?, ascendantSign: String, emptyAngularHouse: Int?
    ) -> String? {
        if !pointsInSign.isEmpty, let signName {
            return "\(cardName) \u{2014} \(signName). Your \(pointsInSign.joined(separator: ", "))."
        }
        if let rulerMatch {
            return "\(cardName) is \(rulerMatch.displayName), and \(rulerMatch.displayName) rules your \(ascendantSign) Ascendant."
        }
        if let signName, let house = emptyAngularHouse {
            return "\(cardName) \u{2014} \(signName). Nothing natal here; your \(ordinal(house)) house."
        }
        return nil
    }

    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 4: return "4th"
        case 7: return "7th"
        case 10: return "10th"
        default: return "\(n)th"
        }
    }
}
