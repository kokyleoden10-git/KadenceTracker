import SwiftData
import SwiftUI

/// v3 spec, Step 1 — the daily loop. Local-only (SwiftData), no auth, no
/// astrology, no sync. Same Entry serves both visits: morning creates the
/// card + line, evening adds the reflection. "Report, don't grade" — no
/// streaks anywhere in this file, and skipping is a first-class save, not
/// an error state.
struct DrawView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt, order: .reverse) private var decks: [Deck]
    @Query(sort: \Entry.occurredAt, order: .reverse) private var entries: [Entry]

    @State private var isCreatingDeck = false
    @State private var selectedDeck: Deck?

    @State private var cardName = ""
    @State private var isReversed = false
    @State private var jumperNames: [String] = []
    @State private var newJumperName = ""
    @State private var morningLine = ""

    @State private var eveningReflection = ""

    private var todaysEntry: Entry? {
        entries.first { Calendar.current.isDateInToday($0.occurredAt) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if decks.isEmpty {
                        noDeckState
                    } else if let entry = todaysEntry, entry.skipped {
                        skippedState(entry)
                    } else if let entry = todaysEntry, entry.dailyDraw != nil {
                        eveningPhase(entry)
                    } else {
                        morningPhase
                    }
                }
                .padding()
            }
            .background(KadenceTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if selectedDeck == nil {
                selectedDeck = entries.first?.deck ?? decks.first
            }
        }
        .sheet(isPresented: $isCreatingDeck) {
            DeckFormView { newDeck in
                selectedDeck = newDeck
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DRAW")
                .font(KadenceTheme.bodyFontSemibold(12))
                .tracking(1.4)
                .foregroundStyle(KadenceTheme.textMuted)
            Text(Date(), style: .date)
                .font(KadenceTheme.displayFont(28))
                .foregroundStyle(KadenceTheme.textPrimary)
        }
    }

    private var noDeckState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No deck set up yet.")
                .font(KadenceTheme.bodyFont(15))
                .foregroundStyle(KadenceTheme.textMuted)
            Button("Add your deck") { isCreatingDeck = true }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(KadenceTheme.piscesTeal)
                .foregroundStyle(KadenceTheme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Morning

    private var morningPhase: some View {
        VStack(alignment: .leading, spacing: 18) {
            deckPicker

            labeledField("Which card did you pull?", placeholder: "e.g. The Star, 9 of Cups", text: $cardName)

            if selectedDeck?.usesReversals == true {
                Toggle(isOn: $isReversed) {
                    Text("Reversed")
                        .font(KadenceTheme.bodyFont(14))
                        .foregroundStyle(KadenceTheme.textPrimary)
                }
                .tint(KadenceTheme.piscesTeal)
            }

            jumperSection

            labeledField("What do you think this is pointing at today?", placeholder: "One line", text: $morningLine)

            HStack(spacing: 12) {
                Button("No pull today") { skipToday() }
                    .font(KadenceTheme.bodyFont(14))
                    .foregroundStyle(KadenceTheme.textMuted)

                Spacer()

                Button("Save") { saveMorning() }
                    .frame(minWidth: 120, minHeight: 44)
                    .background(canSaveMorning ? KadenceTheme.piscesTeal : KadenceTheme.surface)
                    .foregroundStyle(canSaveMorning ? KadenceTheme.bg : KadenceTheme.textMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(!canSaveMorning)
            }
        }
    }

    private var canSaveMorning: Bool {
        !cardName.trimmingCharacters(in: .whitespaces).isEmpty && selectedDeck != nil
    }

    private var deckPicker: some View {
        Menu {
            ForEach(decks) { deck in
                Button(deck.name) { selectedDeck = deck }
            }
            Button("New deck\u{2026}") { isCreatingDeck = true }
        } label: {
            HStack(spacing: 6) {
                Text("Deck: \(selectedDeck?.name ?? "Choose")")
                    .font(KadenceTheme.bodyFont(14))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(KadenceTheme.piscesTeal)
        }
    }

    private var jumperSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Jumpers")
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)

            ForEach(jumperNames, id: \.self) { jumper in
                HStack {
                    Text(jumper)
                        .font(KadenceTheme.bodyFont(14))
                        .foregroundStyle(KadenceTheme.textPrimary)
                    Spacer()
                    Button {
                        jumperNames.removeAll { $0 == jumper }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(KadenceTheme.textMuted)
                    }
                }
                .padding(10)
                .background(KadenceTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                TextField("A card that jumped out", text: $newJumperName)
                    .padding(10)
                    .background(KadenceTheme.surface)
                    .foregroundStyle(KadenceTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button {
                    let trimmed = newJumperName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    jumperNames.append(trimmed)
                    newJumperName = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(KadenceTheme.piscesTeal)
                }
            }
        }
    }

    // MARK: - Evening

    private func eveningPhase(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.dailyDraw?.cardName ?? "")
                    .font(KadenceTheme.displayFont(24))
                    .foregroundStyle(KadenceTheme.textPrimary)
                if entry.dailyDraw?.reversed == true {
                    Text("Reversed")
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.textMuted)
                }
                if !entry.jumperDraws.isEmpty {
                    Text("Jumpers: \(entry.jumperDraws.map(\.cardName).joined(separator: ", "))")
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.textMuted)
                }
                if let line = entry.morningRead, !line.isEmpty {
                    Text("\u{201C}\(line)\u{201D}")
                        .font(KadenceTheme.bodyFont(14))
                        .italic()
                        .foregroundStyle(KadenceTheme.piscesSeafoam.opacity(0.9))
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .background(KadenceTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            labeledField("What happened? Does it read differently now?", placeholder: "Reflection", text: $eveningReflection)

            Button("Save") { saveEvening(entry) }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(KadenceTheme.piscesTeal)
                .foregroundStyle(KadenceTheme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onAppear { eveningReflection = entry.eveningReflection ?? "" }
    }

    private func skippedState(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No pull today.")
                .font(KadenceTheme.bodyFont(15))
                .foregroundStyle(KadenceTheme.textMuted)
            Button("Actually, let me log one") {
                entry.skipped = false
                entry.updatedAt = Date()
            }
            .font(KadenceTheme.bodyFont(14))
            .foregroundStyle(KadenceTheme.piscesTeal)
        }
    }

    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
            TextField(placeholder, text: text, axis: .vertical)
                .padding(10)
                .background(KadenceTheme.surface)
                .foregroundStyle(KadenceTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Actions

    private func saveMorning() {
        guard let deck = selectedDeck else { return }
        let entry = todaysEntry ?? Entry(occurredAt: Calendar.current.startOfDay(for: Date()))
        if todaysEntry == nil { modelContext.insert(entry) }

        entry.deck = deck
        entry.morningRead = morningLine.isEmpty ? nil : morningLine
        entry.skipped = false
        entry.updatedAt = Date()

        let daily = Draw(cardName: cardName.trimmingCharacters(in: .whitespaces), role: .daily, reversed: isReversed)
        entry.draws.append(daily)
        for jumper in jumperNames {
            entry.draws.append(Draw(cardName: jumper, role: .jumper))
        }

        cardName = ""
        isReversed = false
        jumperNames = []
        morningLine = ""
    }

    private func saveEvening(_ entry: Entry) {
        entry.eveningReflection = eveningReflection.isEmpty ? nil : eveningReflection
        entry.updatedAt = Date()
    }

    private func skipToday() {
        let entry = todaysEntry ?? Entry(occurredAt: Calendar.current.startOfDay(for: Date()))
        if todaysEntry == nil { modelContext.insert(entry) }
        entry.skipped = true
        entry.updatedAt = Date()
    }
}

#Preview {
    DrawView()
        .modelContainer(for: [Deck.self, Entry.self, Draw.self], inMemory: true)
}
