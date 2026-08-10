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
    var role: DrawRole
    var reversed: Bool
    var createdAt: Date
    var resonanceTier: String?
    var resonanceNote: String?

    init(cardName: String, role: DrawRole = .daily, reversed: Bool = false) {
        self.cardName = cardName
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
