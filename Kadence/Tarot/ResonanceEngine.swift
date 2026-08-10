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
        var score = 0
        var pointsInSign: [String] = []
        var matchedSign: ZodiacSign?

        for point in NatalPoint.allCases {
            let sign = point.sign(in: chart)
            if card.signs.contains(sign) {
                score += point.weight
                pointsInSign.append(point.displayName)
                if matchedSign == nil { matchedSign = sign }
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

        for sign in card.signs where !pointsInSign.isEmpty {
            if let house = chart.house(of: sign), angularHouses.contains(house) {
                score += 1
            }
        }

        let elementStanding = notableElement(for: card, chart: chart)
        let modalityStanding = notableModality(for: card, chart: chart)
        if elementStanding != nil { score += 2 }
        if modalityStanding != nil { score += 1 }

        let tier: ResonanceTier
        switch score {
        case 0...1: tier = .quiet
        case 2...4: tier = .active
        default: tier = .loud
        }

        let note = noteText(
            matchedSign: matchedSign?.displayName,
            pointsInSign: pointsInSign,
            rulerMatch: rulerMatch,
            ascendantSign: chart.ascendant.displayName,
            elementStanding: elementStanding,
            modalityStanding: modalityStanding
        )
        return ResonanceResult(tier: tier, note: note)
    }

    /// Where a card's quality sits in the chart's distribution. Affirming
    /// only — a quality the chart doesn't have at all produces nothing,
    /// deliberately. (Spec's "conspicuously empty" case is dropped: read
    /// back on a real draw, telling someone what they lack is the opposite
    /// of the instrument being useful.)
    private enum Standing {
        case densest(String, Int)
        case rarest(String, Int)
    }

    /// Majors carry no explicit element/modality in the catalog, so derive
    /// both from the card's sign when present. Aces have an element but no
    /// sign, which is the case spec singles out for element treatment.
    private static func standing<Q: Hashable>(
        of quality: Q?, tally: [Q: Int], name: (Q) -> String
    ) -> Standing? {
        guard let quality, let count = tally[quality], count > 0 else { return nil }
        let counts = tally.values.sorted()
        guard let lowest = counts.first, let highest = counts.last, highest != lowest else { return nil }
        // Ties don't qualify — "densest" should mean singular, or it's just
        // one of several and not worth calling out.
        if count == highest, tally.values.filter({ $0 == highest }).count == 1 {
            return .densest(name(quality), count)
        }
        if count == lowest, tally.values.filter({ $0 == lowest }).count == 1 {
            return .rarest(name(quality), count)
        }
        return nil
    }

    private static func notableElement(for card: TarotCard, chart: NatalChart) -> Standing? {
        let cardElement = card.element ?? card.signs.first.map(element(of:))
        return standing(of: cardElement, tally: chart.elementTally) { $0.displayName }
    }

    private static func notableModality(for card: TarotCard, chart: NatalChart) -> Standing? {
        let cardModality = card.signs.first.map(modality(of:))
        return standing(of: cardModality, tally: chart.modalityTally) { $0.displayName }
    }

    private static func phrase(_ standing: Standing, kind: String) -> String {
        let total = NatalChart.talliedPointCount
        switch standing {
        case .densest(let name, let count):
            return "\(name) is your densest \(kind) \u{2014} \(count) of \(total)."
        case .rarest(let name, let count):
            return "\(name) is your rarest \(kind) \u{2014} \(count) of \(total)."
        }
    }

    /// Affirming only, and never repeats the card's name — the card title
    /// is already the heading directly above this note in the UI.
    ///
    /// Every case here states something the chart actually *has*, and how
    /// much of it. Nothing fires for a quality the chart lacks, so silence
    /// carries the "no connection today" meaning by itself, which also
    /// keeps spec's "silence is a feature" rule intact: element/modality
    /// only speak when singularly densest or rarest, never on a mere match.
    private static func noteText(
        matchedSign: String?, pointsInSign: [String],
        rulerMatch: Planet?, ascendantSign: String,
        elementStanding: Standing?, modalityStanding: Standing?
    ) -> String? {
        if !pointsInSign.isEmpty, let matchedSign {
            return "Your \(list(pointsInSign)) in \(matchedSign)."
        }
        if let rulerMatch {
            return "\(rulerMatch.displayName) rules your \(ascendantSign) Ascendant."
        }
        if let elementStanding {
            return phrase(elementStanding, kind: "element")
        }
        if let modalityStanding {
            return phrase(modalityStanding, kind: "modality")
        }
        return nil
    }

    private static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }
}
