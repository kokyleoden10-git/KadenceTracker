import Foundation
import SwiftData

/// One-time move of the locally-stored card log into Supabase.
///
/// Deliberately non-destructive: the SwiftData copy is left in place after a
/// successful run. It costs a trivial amount of disk and it's the only
/// backup of data that existed nowhere else, so deleting it to feel tidy
/// would be the one irreversible step in an otherwise reversible change.
///
/// Runs at most once per device (a UserDefaults flag), and only with a
/// signed-in session, since every row needs a user_id.
@MainActor
enum TarotMigrationService {
    private static let flagKey = "tarotMigratedToSupabase"

    static var hasMigrated: Bool {
        UserDefaults.standard.bool(forKey: flagKey)
    }

    struct Result {
        var decks = 0
        var charts = 0
        var entries = 0
        var draws = 0
        var isEmpty: Bool { decks == 0 && charts == 0 && entries == 0 }
    }

    /// Returns nil when there was nothing to do (already migrated, or no
    /// local data). Throws only on a genuine failure — the flag is set only
    /// after everything has landed, so a failed run retries next launch
    /// rather than silently losing rows.
    @discardableResult
    static func migrateIfNeeded(context: ModelContext) async throws -> Result? {
        guard !hasMigrated else { return nil }
        guard await SupabaseService.shared.userIdIfSignedIn() != nil else { return nil }

        var result = Result()

        // Decks first — entries reference them.
        let localDecks = try context.fetch(FetchDescriptor<Deck>())
        var deckIdByName: [String: UUID] = [:]
        let existingRemote = try await DeckService.fetchActive()
        for remote in existingRemote {
            deckIdByName[remote.name] = remote.id
        }
        for deck in localDecks where deckIdByName[deck.name] == nil {
            let created = try await DeckService.create(
                name: deck.name,
                tradition: deck.tradition,
                usesReversals: deck.usesReversals
            )
            deckIdByName[deck.name] = created.id
            result.decks += 1
        }

        // Chart — upsert on user_id, so a chart already entered remotely
        // wins over re-pushing the local one only in the sense that the
        // local one overwrites it. There is at most one of each, and the
        // local copy is the one the user has actually been looking at.
        if try await NatalChartService.fetch() == nil,
           let chart = try context.fetch(FetchDescriptor<NatalChart>()).first {
            try await NatalChartService.save(
                NatalChartService.ChartInput(
                    userId: try await SupabaseService.shared.requireUserId(),
                    sun: chart.sun, moon: chart.moon, mercury: chart.mercury,
                    venus: chart.venus, mars: chart.mars, jupiter: chart.jupiter,
                    saturn: chart.saturn, uranus: chart.uranus, neptune: chart.neptune,
                    pluto: chart.pluto, ascendant: chart.ascendant, midheaven: chart.midheaven,
                    birthDateDescription: chart.birthDateDescription,
                    birthTimeDescription: chart.birthTimeDescription,
                    birthLocationDescription: chart.birthLocationDescription,
                    userNote: chart.userNote
                )
            )
            result.charts += 1
        }

        // Entries, skipping any date that already exists remotely so a
        // partial previous run can't duplicate a day.
        let remoteDates = Set(try await EntryService.fetchAll().map(\.entry.date))
        let localEntries = try context.fetch(FetchDescriptor<Entry>())
        let userId = try await SupabaseService.shared.requireUserId()

        for local in localEntries {
            let dateString = SupabaseDate.string(local.occurredAt)
            guard !remoteDates.contains(dateString) else { continue }

            let entry = try await EntryService.upsert(
                EntryService.EntryInput(
                    userId: userId,
                    date: dateString,
                    deckId: local.deck.flatMap { deckIdByName[$0.name] },
                    skipped: local.skipped,
                    morningRead: local.morningRead,
                    eveningReflection: local.eveningReflection,
                    updatedAt: local.updatedAt
                )
            )
            result.entries += 1

            let draws = local.draws.map { draw in
                EntryService.DrawInput(
                    userId: userId,
                    entryId: entry.id,
                    cardId: draw.cardID,
                    cardName: draw.cardName,
                    role: draw.role,
                    reversed: draw.reversed,
                    resonanceTier: draw.resonanceTier,
                    resonanceNote: draw.resonanceNote
                )
            }
            try await EntryService.addDraws(draws)
            result.draws += draws.count
        }

        UserDefaults.standard.set(true, forKey: flagKey)
        return result
    }
}
