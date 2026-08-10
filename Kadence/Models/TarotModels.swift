import Foundation
import SwiftData

/// v3 spec, Step 1 — local-only, no auth, no astrology. SwiftData is the
/// full source of truth for this flow (not a cache in front of Supabase,
/// unlike the habit tables) — nothing here talks to the network at all yet.
///
/// `resonanceTier`/`resonanceNote` on Draw are declared now but never set —
/// they're frozen at draw time once the astrology engine (spec Step 3)
/// exists, so declaring the fields now means that's a fill-in later, not a
/// migration. NatalChart/SkyStamp/BodyStamp aren't declared at all yet:
/// unlike these two fields, they're whole new models with no present use,
/// and adding a new @Model class later needs no migration from existing
/// data, so there's no cost to waiting until Steps 3/5 actually need them.

enum DrawRole: String, Codable, CaseIterable {
    case daily, jumper
}

enum Tradition: String, Codable, CaseIterable {
    case rws = "Rider-Waite-Smith"
    case thoth = "Thoth"
    case marseille = "Marseille"
    case other = "Other"
}

@Model
final class Deck {
    var name: String
    var tradition: Tradition
    var usesReversals: Bool
    var createdAt: Date

    init(name: String, tradition: Tradition = .rws, usesReversals: Bool = true) {
        self.name = name
        self.tradition = tradition
        self.usesReversals = usesReversals
        self.createdAt = Date()
    }
}

@Model
final class Draw {
    var cardName: String
    var cardID: String?
    var role: DrawRole
    var reversed: Bool
    var createdAt: Date
    var resonanceTier: String?
    var resonanceNote: String?

    init(cardName: String, cardID: String? = nil, role: DrawRole = .daily, reversed: Bool = false) {
        self.cardName = cardName
        self.cardID = cardID
        self.role = role
        self.reversed = reversed
        self.createdAt = Date()
    }
}

@Model
final class Entry {
    var occurredAt: Date
    var createdAt: Date
    var updatedAt: Date
    var skipped: Bool

    var deck: Deck?
    @Relationship(deleteRule: .cascade) var draws: [Draw]

    var morningRead: String?
    var eveningReflection: String?

    init(occurredAt: Date) {
        self.occurredAt = occurredAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.skipped = false
        self.draws = []
    }

    var dailyDraw: Draw? { draws.first { $0.role == .daily } }
    var jumperDraws: [Draw] { draws.filter { $0.role == .jumper } }
}

/// Sign-level only, entered directly by the user rather than computed from
/// an ephemeris — holding off on Swiss Ephemeris (AGPL dependency, and a
/// natal chart never changes once computed, so there's no ongoing need for
/// a live engine) means trusting a chart the user already has from
/// elsewhere. That's sufficient for spec's own resonance scoring, which
/// only ever checks sign membership, never exact degree.
///
/// Houses use whole-sign (12th sign back through 11th sign forward from
/// Ascendant) — the simplest traditional house system, and it needs
/// nothing beyond the Ascendant sign already captured here.
@Model
final class NatalChart {
    var sun: ZodiacSign
    var moon: ZodiacSign
    var mercury: ZodiacSign
    var venus: ZodiacSign
    var mars: ZodiacSign
    var jupiter: ZodiacSign
    var saturn: ZodiacSign
    var uranus: ZodiacSign
    var neptune: ZodiacSign
    var pluto: ZodiacSign
    var ascendant: ZodiacSign
    var midheaven: ZodiacSign

    var birthDateDescription: String?
    var birthTimeDescription: String?
    var birthLocationDescription: String?
    var userNote: String?
    var createdAt: Date

    init(
        sun: ZodiacSign, moon: ZodiacSign, mercury: ZodiacSign, venus: ZodiacSign,
        mars: ZodiacSign, jupiter: ZodiacSign, saturn: ZodiacSign, uranus: ZodiacSign,
        neptune: ZodiacSign, pluto: ZodiacSign, ascendant: ZodiacSign, midheaven: ZodiacSign
    ) {
        self.sun = sun
        self.moon = moon
        self.mercury = mercury
        self.venus = venus
        self.mars = mars
        self.jupiter = jupiter
        self.saturn = saturn
        self.uranus = uranus
        self.neptune = neptune
        self.pluto = pluto
        self.ascendant = ascendant
        self.midheaven = midheaven
        self.createdAt = Date()
    }

    var placements: [Planet: ZodiacSign] {
        [.sun: sun, .moon: moon, .mercury: mercury, .venus: venus, .mars: mars,
         .jupiter: jupiter, .saturn: saturn, .uranus: uranus, .neptune: neptune, .pluto: pluto]
    }

    /// Whole-sign houses: the Ascendant's sign is the 1st house, and the
    /// rest follow in zodiac order. `houses[0]` is the 1st house.
    var houses: [ZodiacSign] {
        let signs = ZodiacSign.allCases
        guard let startIndex = signs.firstIndex(of: ascendant) else { return signs }
        return (0..<12).map { signs[(startIndex + $0) % 12] }
    }

    func house(of sign: ZodiacSign) -> Int? {
        houses.firstIndex(of: sign).map { $0 + 1 }
    }

    var elementTally: [Element: Int] {
        var tally: [Element: Int] = [.fire: 0, .water: 0, .air: 0, .earth: 0]
        for sign in placements.values {
            tally[element(of: sign), default: 0] += 1
        }
        return tally
    }
}

func element(of sign: ZodiacSign) -> Element {
    switch sign {
    case .aries, .leo, .sagittarius: return .fire
    case .taurus, .virgo, .capricorn: return .earth
    case .gemini, .libra, .aquarius: return .air
    case .cancer, .scorpio, .pisces: return .water
    }
}
