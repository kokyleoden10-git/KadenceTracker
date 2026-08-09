import Foundation

/// Static curated list (spec §11) — no API. Picks a stable "quote of the
/// day" so it doesn't change on every screen refresh.
enum Quotes {
    struct Quote {
        let text: String
        let source: String
    }

    static let all: [Quote] = [
        Quote(text: "The two-minute rule: if it takes less than two minutes, do it now.", source: "Atomic Habits"),
        Quote(text: "You do not rise to the level of your goals. You fall to the level of your systems.", source: "Atomic Habits"),
        Quote(text: "Every habit starts with a cue.", source: "The Power of Habit"),
        Quote(text: "Champions don't do extraordinary things. They do ordinary things, but they do them without thinking.", source: "The Power of Habit"),
        Quote(text: "The key is not to prioritize what's on your schedule, but to schedule your priorities.", source: "7 Habits of Highly Effective People"),
        Quote(text: "Begin with the end in mind.", source: "7 Habits of Highly Effective People"),
        Quote(text: "Habits are the compound interest of self-improvement.", source: "Atomic Habits"),
    ]

    static func forToday(_ date: Date = .init()) -> Quote {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return all[dayOfYear % all.count]
    }
}
