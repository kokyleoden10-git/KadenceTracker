import SwiftData
import SwiftUI

/// v3 spec, Step 1 + resonance (§Resonance) — the daily loop plus card
/// attribution against a natal chart.
///
/// Now Supabase-backed rather than SwiftData: one store for the whole app,
/// so a day's card and a day's habits live side by side and can be read
/// together. The tradeoff, accepted deliberately, is that this screen needs
/// a signed-in session and a network connection — there is no offline
/// logging. `TarotMigrationService` moves anything previously stored on
/// device across on first launch.
struct DrawView: View {
    /// Only still here so the one-time migration can read the old local
    /// store. Nothing in this view writes to it.
    @Environment(\.modelContext) private var modelContext

    @State private var decks: [RemoteDeck] = []
    @State private var chart: RemoteNatalChart?
    @State private var profile: Profile?
    @State private var todaysEntry: EntryWithDraws?
    @State private var status = ""
    /// Kept separate from `status`: a successful migration was rendering in
    /// the error colour because both shared one variable.
    @State private var infoMessage: String?
    @State private var isLoading = true

    /// The evening half of the ritual shouldn't open the moment the morning
    /// half is saved. Settable rather than fixed at 8pm, and with an
    /// override, so the app nudges the rhythm without refusing.
    @AppStorage("eveningUnlockHour") private var eveningUnlockHour = 20
    @State private var hasOverriddenEveningGate = false

    @State private var isCreatingDeck = false
    @State private var isPickingCard = false
    @State private var isShowingHistory = false
    @State private var selectedDeck: RemoteDeck?

    @State private var selectedCard: TarotCard?
    @State private var isReversed = false
    @State private var jumperNames: [String] = []
    @State private var newJumperName = ""
    @State private var morningLine = ""

    @State private var eveningReflection = ""
    @State private var isConfirmingClear = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if isLoading {
                        ProgressView().tint(KadenceTheme.textPrimary)
                    } else if decks.isEmpty {
                        noDeckState
                    } else if let entry = todaysEntry, entry.entry.skipped {
                        skippedState(entry)
                    } else if let entry = todaysEntry, entry.dailyDraw != nil {
                        if isEveningUnlocked {
                            eveningPhase(entry)
                        } else {
                            loggedAndWaiting(entry)
                        }
                    } else {
                        morningPhase
                    }

                    if let infoMessage {
                        Text(infoMessage)
                            .font(KadenceTheme.bodyFont(12))
                            .foregroundStyle(KadenceTheme.textMuted)
                    }

                    if !status.isEmpty {
                        Text(status)
                            .font(KadenceTheme.bodyFont(12))
                            .foregroundStyle(KadenceTheme.ariesEmber)
                    }
                }
                .padding()
            }
            .background(KadenceTheme.bg.ignoresSafeArea())
            .refreshable { await load() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(KadenceTheme.piscesTeal)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        .sheet(isPresented: $isShowingHistory) {
            HistoryView()
        }
        .sheet(isPresented: $isCreatingDeck) {
            DeckFormView { newDeck in
                selectedDeck = newDeck
                Task { await load() }
            }
        }
        .sheet(isPresented: $isPickingCard) {
            CardPickerView(tradition: selectedDeck?.traditionValue ?? .rws) { card in
                selectedCard = card
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(KadenceTheme.personalizedTitle(nickname: profile?.nickname, screen: "Draw"))
                    .font(KadenceTheme.bodyFontSemibold(12))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(KadenceTheme.textMuted)
                Text(Date(), style: .date)
                    .font(KadenceTheme.displayFont(28))
                    .foregroundStyle(KadenceTheme.textPrimary)
            }
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Which card did you pull?")
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
                Button {
                    isPickingCard = true
                } label: {
                    Text(selectedCard.map { $0.name(for: selectedDeck?.traditionValue ?? .rws) } ?? "Choose a card")
                        .font(KadenceTheme.bodyFont(15))
                        .foregroundStyle(selectedCard == nil ? KadenceTheme.textMuted : KadenceTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(KadenceTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

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
                Button("No pull today") { Task { await skipToday() } }
                    .font(KadenceTheme.bodyFont(14))
                    .foregroundStyle(KadenceTheme.textMuted)

                Spacer()

                Button {
                    Task { await saveMorning() }
                } label: {
                    Group {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .frame(minWidth: 120, minHeight: 44)
                }
                .background(canSaveMorning ? KadenceTheme.piscesTeal : KadenceTheme.surface)
                .foregroundStyle(canSaveMorning ? KadenceTheme.bg : KadenceTheme.textMuted)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!canSaveMorning || isSaving)
            }
        }
    }

    private var canSaveMorning: Bool {
        selectedCard != nil && selectedDeck != nil
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

    private var isEveningUnlocked: Bool {
        hasOverriddenEveningGate
            || Calendar.current.component(.hour, from: Date()) >= eveningUnlockHour
    }

    private func unlockDescription() -> String {
        var components = DateComponents()
        components.hour = eveningUnlockHour
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Today's card is drawn and the line is written, but it's still daytime.
    /// Reflecting an hour after drawing defeats the point of reflecting, so
    /// the field stays closed until evening — with a way through for someone
    /// turning in early.
    private func loggedAndWaiting(_ entry: EntryWithDraws) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            cardCard(entry)

            Text("Come back after \(unlockDescription()) to reflect on how it read.")
                .font(KadenceTheme.bodyFont(13))
                .foregroundStyle(KadenceTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            Button("Reflect now anyway") { hasOverriddenEveningGate = true }
                .font(KadenceTheme.bodyFont(13))
                .foregroundStyle(KadenceTheme.piscesTeal)

            clearTodayButton(entry)
        }
    }

    private func cardCard(_ entry: EntryWithDraws) -> some View {
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
            // Tier 1 (spec's Reference tiers) — plain attribution facts,
            // always shown, no personalization. Shown before the resonance
            // note on purpose: "Cardinal is your rarest modality" means
            // nothing until you know the card itself is Libra.
            if let attribution = entry.dailyDraw?.card?.attributionLine {
                Text(attribution)
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
                    .padding(.top, 4)
            }

            if let line = entry.entry.morningRead, !line.isEmpty {
                Text("\u{201C}\(line)\u{201D}")
                    .font(KadenceTheme.bodyFont(14))
                    .italic()
                    .foregroundStyle(KadenceTheme.piscesSeafoam.opacity(0.9))
                    .padding(.top, 4)
            }
            // Frozen at draw time, so it still reads as it did on the day
            // even if the chart is corrected later. Its own label makes
            // clear this line is personalized, unlike the attribution
            // above it.
            if let note = entry.dailyDraw?.resonanceNote {
                Text("Yours: \(note)")
                    .font(KadenceTheme.bodyFont(13))
                    .foregroundStyle(KadenceTheme.piscesTeal)
                    .padding(.top, 6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KadenceTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Escape hatch for logging out of order (e.g. drawing before the chart
    /// was set, which freezes a resonance note of nil). Deliberately
    /// understated — this isn't part of the daily ritual, and "start over"
    /// shouldn't read as a judgment.
    private func clearTodayButton(_ entry: EntryWithDraws) -> some View {
        Button("Clear today and start over") { isConfirmingClear = true }
            .font(KadenceTheme.bodyFont(13))
            .foregroundStyle(KadenceTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .confirmationDialog(
                "This deletes today's card, your morning line, and any reflection, so you can log the day again. Past days aren't affected.",
                isPresented: $isConfirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear Today", role: .destructive) { Task { await clearToday(entry) } }
                Button("Cancel", role: .cancel) {}
            }
    }

    private func eveningPhase(_ entry: EntryWithDraws) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            cardCard(entry)

            labeledField("What happened? Does it read differently now?", placeholder: "Reflection", text: $eveningReflection)

            Button {
                Task { await saveEvening(entry) }
            } label: {
                Group {
                    if isSaving { ProgressView() } else { Text("Save") }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .background(KadenceTheme.piscesTeal)
            .foregroundStyle(KadenceTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(isSaving)

            clearTodayButton(entry)
        }
        .onAppear { eveningReflection = entry.entry.eveningReflection ?? "" }
    }

    private func skippedState(_ entry: EntryWithDraws) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No pull today.")
                .font(KadenceTheme.bodyFont(15))
                .foregroundStyle(KadenceTheme.textMuted)
            Button("Actually, let me log one") {
                Task { await unskip(entry) }
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

    // MARK: - Load

    private func load() async {
        do {
            // Runs at most once, and only while signed in. Non-destructive:
            // the local copy is left alone. Errors are surfaced rather than
            // swallowed — a migration that silently fails looks identical
            // to one that had nothing to do, and the flag is only set on
            // success, so a reported failure will retry next launch.
            do {
                if let moved = try await TarotMigrationService.migrateIfNeeded(context: modelContext), !moved.isEmpty {
                    infoMessage = movedDescription(moved)
                }
            } catch {
                status = "Couldn't move this device's saved draws: \(error.localizedDescription). Your local copy is untouched; this will retry."
            }

            async let decksTask = DeckService.fetchActive()
            async let chartTask = NatalChartService.fetch()
            async let entryTask = EntryService.fetchForDate()
            async let profileTask = ProfileService.fetchCurrent()

            decks = try await decksTask
            chart = try await chartTask
            todaysEntry = try await entryTask
            profile = try await profileTask

            if selectedDeck == nil || !decks.contains(where: { $0.id == selectedDeck?.id }) {
                selectedDeck = decks.first
            }
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            status = "Couldn't load: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func movedDescription(_ moved: TarotMigrationService.Result) -> String {
        var parts: [String] = []
        if moved.entries > 0 { parts.append(moved.entries == 1 ? "1 day" : "\(moved.entries) days") }
        if moved.decks > 0 { parts.append(moved.decks == 1 ? "your deck" : "\(moved.decks) decks") }
        if moved.charts > 0 { parts.append("your chart") }
        return "Synced \(list(parts)) from this device to your account."
    }

    private func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }

    // MARK: - Actions

    private func saveMorning() async {
        guard let deck = selectedDeck, let card = selectedCard else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let userId = try await SupabaseService.shared.requireUserId()
            let entry = try await EntryService.upsert(
                EntryService.EntryInput(
                    userId: userId,
                    date: SupabaseDate.string(),
                    deckId: deck.id,
                    skipped: false,
                    morningRead: morningLine.isEmpty ? nil : morningLine,
                    eveningReflection: nil,
                    updatedAt: Date()
                )
            )

            var resonanceTier: String?
            var resonanceNote: String?
            if let chart {
                let result = ResonanceEngine.resonance(
                    for: card,
                    deckTradition: deck.traditionValue,
                    chart: chart.placements
                )
                resonanceTier = result.tier.rawValue
                resonanceNote = result.note
            }

            var inputs = [EntryService.DrawInput(
                userId: userId,
                entryId: entry.id,
                cardId: card.id,
                cardName: card.name(for: deck.traditionValue),
                role: .daily,
                reversed: isReversed,
                resonanceTier: resonanceTier,
                resonanceNote: resonanceNote
            )]
            // Jumpers stay free text for now — resonance for them is
            // deferred, not wired into this pass's UI.
            inputs += jumperNames.map {
                EntryService.DrawInput(
                    userId: userId, entryId: entry.id, cardId: nil, cardName: $0,
                    role: .jumper, reversed: false, resonanceTier: nil, resonanceNote: nil
                )
            }
            try await EntryService.addDraws(inputs)

            selectedCard = nil
            isReversed = false
            jumperNames = []
            morningLine = ""
            await load()
        } catch {
            status = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func saveEvening(_ entry: EntryWithDraws) async {
        isSaving = true
        defer { isSaving = false }
        await patch(entry, eveningReflection: eveningReflection.isEmpty ? nil : eveningReflection)
    }

    private func unskip(_ entry: EntryWithDraws) async {
        await patch(entry, skipped: false)
    }

    /// Upsert carries every field, so anything not being changed has to be
    /// passed through from the existing row rather than left out.
    private func patch(
        _ entry: EntryWithDraws,
        skipped: Bool? = nil,
        eveningReflection: String?? = nil
    ) async {
        do {
            try await EntryService.patch(entry.entry, skipped: skipped, eveningReflection: eveningReflection)
            await load()
        } catch {
            status = "Couldn't save: \(error.localizedDescription)"
        }
    }

    /// Deletes the whole row rather than just its draws — `draw.entry_id` is
    /// `on delete cascade`, so this clears the draws too, and dropping the
    /// row puts the day back to never-logged, which is what "start over"
    /// should mean.
    private func clearToday(_ entry: EntryWithDraws) async {
        do {
            try await EntryService.deleteEntry(id: entry.entry.id)
            selectedCard = nil
            isReversed = false
            jumperNames = []
            morningLine = ""
            eveningReflection = ""
            await load()
        } catch {
            status = "Couldn't clear: \(error.localizedDescription)"
        }
    }

    private func skipToday() async {
        do {
            try await EntryService.upsert(
                EntryService.EntryInput(
                    userId: try await SupabaseService.shared.requireUserId(),
                    date: SupabaseDate.string(),
                    deckId: selectedDeck?.id,
                    skipped: true,
                    morningRead: nil,
                    eveningReflection: nil,
                    updatedAt: Date()
                )
            )
            await load()
        } catch {
            status = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

#Preview {
    DrawView()
        .modelContainer(for: [Deck.self, Entry.self, Draw.self, NatalChart.self], inMemory: true)
}
