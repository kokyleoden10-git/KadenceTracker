import SwiftUI

enum HabitGroupMode: String, CaseIterable {
    case none = "Default Order"
    case domain = "By Domain"
    case tier = "By Tier"
}

/// Spec §8 step 2 — the 2-minute-a-day surface. Shows only today's active
/// Anchors + Practices (per days_active), not every habit ever created
/// (that's ManageHabitsView). Tapping a habit's checkbox is the entire
/// interaction for the common case; the detail sheet and edit form are
/// both one tap further away, never in the primary path.
struct HomeView: View {
    @State private var habits: [Habit] = []
    @State private var logEntries: [UUID: LogEntry] = [:]
    @State private var profile: Profile?
    @State private var status = "Loading\u{2026}"

    @AppStorage("homeGroupMode") private var groupModeRaw = HabitGroupMode.none.rawValue
    private var groupMode: HabitGroupMode { HabitGroupMode(rawValue: groupModeRaw) ?? .none }

    @State private var isManagingHabits = false
    @State private var isCreatingHabit = false
    @State private var editHabit: Habit?
    @State private var detailHabit: Habit?
    @State private var detailNote = ""
    @State private var detailTags: [String] = []
    @State private var detailBreakContext = ""

    private var todaysHabits: [Habit] {
        let todayIndex = LogEntryService.todayWeekdayIndex()
        return habits.filter { $0.daysActive.contains(todayIndex) }
    }

    /// Empty groups are dropped — no point showing a "Systems" header for a
    /// day with nothing scheduled in that domain (spec's own "not every
    /// domain needs attention every day").
    private var groupedSections: [(title: String, color: Color?, habits: [Habit])] {
        switch groupMode {
        case .none:
            return [("", nil, todaysHabits)]
        case .domain:
            return Domain.allCases.compactMap { domain in
                let matches = todaysHabits.filter { $0.domain == domain }
                guard !matches.isEmpty else { return nil }
                return (domain.rawValue.capitalized, KadenceTheme.color(for: domain), matches)
            }
        case .tier:
            let anchors = todaysHabits.filter { $0.tier == .anchor }
            let practices = todaysHabits.filter { $0.tier == .practice }
            var sections: [(String, Color?, [Habit])] = []
            if !anchors.isEmpty { sections.append(("Anchors", nil, anchors)) }
            if !practices.isEmpty { sections.append(("Practices \u{00B7} important, not urgent", nil, practices)) }
            return sections
        }
    }

    var body: some View {
        NavigationStack {
            List {
                HomeHeaderView(profile: profile, status: status)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))

                if todaysHabits.isEmpty && status.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 16, trailing: 16))
                } else {
                    if !todaysHabits.isEmpty {
                        sortControl
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 2, trailing: 16))
                    }

                    ForEach(groupedSections, id: \.title) { section in
                        if !section.title.isEmpty {
                            HStack(spacing: 6) {
                                if let color = section.color {
                                    Circle().fill(color).frame(width: 8, height: 8)
                                }
                                Text(section.title.uppercased())
                                    .font(KadenceTheme.bodyFontSemibold(11))
                                    .tracking(1)
                            }
                            .foregroundStyle(KadenceTheme.textMuted)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 2, trailing: 16))
                        }

                        ForEach(section.habits) { habit in
                            DailyHabitRow(
                                habit: habit,
                                state: state(for: habit),
                                onToggleDone: { toggleDone(habit) },
                                onOpenDetail: { openDetail(habit) },
                                onEdit: { editHabit = habit }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // Deliberately not red/destructive-styled — a
                                // skipped day isn't an error state (spec §1:
                                // "instrument, not judge").
                                Button("Not Done") { markNotDone(habit) }
                                    .tint(KadenceTheme.textMuted)
                                if state(for: habit) != .notLogged {
                                    Button("Clear", role: .destructive) { clearLog(habit) }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(KadenceTheme.bg.ignoresSafeArea())
            .refreshable { await load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isManagingHabits = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(KadenceTheme.piscesTeal)
                    }
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $isManagingHabits, onDismiss: { Task { await load() } }) {
            ManageHabitsView()
        }
        .sheet(isPresented: $isCreatingHabit) {
            HabitFormView(mode: .create) {
                Task { await load() }
            }
        }
        .sheet(item: $editHabit) { habit in
            HabitFormView(mode: .edit(habit)) {
                Task { await load() }
            }
        }
        .sheet(item: $detailHabit) { habit in
            LogDetailSheet(
                habit: habit,
                showBreakContext: state(for: habit) == .notDone,
                note: $detailNote,
                tags: $detailTags,
                breakContext: $detailBreakContext,
                onSave: { saveDetail(habit) }
            )
        }
    }

    /// The primary action here is always a direct, one-tap route to the
    /// create form — never a stop at Manage Habits first. That used to be
    /// a real double-click bug: this button opened the (empty) Manage
    /// Habits list, which still required tapping its own "+" to actually
    /// reach the form.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing scheduled for today.")
                .font(KadenceTheme.bodyFont(15))
                .foregroundStyle(KadenceTheme.textMuted)

            Button {
                isCreatingHabit = true
            } label: {
                Text(habits.isEmpty ? "Add your first habit" : "Add New Habit")
                    .font(KadenceTheme.bodyFontSemibold(15))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .background(KadenceTheme.piscesTeal)
            .foregroundStyle(KadenceTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if !habits.isEmpty {
                Button("Manage habits") { isManagingHabits = true }
                    .font(KadenceTheme.bodyFont(13))
                    .foregroundStyle(KadenceTheme.textMuted)
            }
        }
    }

    /// Sits directly above the list it sorts, rather than off in the nav
    /// bar where its purpose was unclear — and only appears when there's
    /// something to sort at all.
    private var sortControl: some View {
        HStack {
            Spacer()
            Menu {
                Picker("Sort", selection: $groupModeRaw) {
                    ForEach(HabitGroupMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
                    Text(groupMode.rawValue)
                        .font(KadenceTheme.bodyFont(12))
                }
                .foregroundStyle(KadenceTheme.piscesTeal)
            }
        }
    }

    private func state(for habit: Habit) -> DailyLogState {
        guard let entry = logEntries[habit.id] else { return .notLogged }
        return entry.doneValue > 0 ? .done : .notDone
    }

    private func load() async {
        do {
            async let profileTask = ProfileService.fetchCurrent()
            async let habitsTask = HabitService.fetchActive()
            async let entriesTask = LogEntryService.fetchForDate()
            profile = try await profileTask
            habits = try await habitsTask
            let entries = try await entriesTask
            logEntries = Dictionary(uniqueKeysWithValues: entries.map { ($0.habitId, $0) })
            status = ""
        } catch is CancellationError {
            // A superseded reload (e.g. this view's .task restarting when a
            // sheet dismisses) isn't a real failure — a newer load() already
            // reflects the correct state.
        } catch {
            status = "Couldn't load data: \(error.localizedDescription)"
        }
    }

    private func setDone(_ habit: Habit, doneValue: Int) {
        Task {
            let existing = logEntries[habit.id]
            let input = LogEntryService.LogEntryInput(
                habitId: habit.id,
                date: LogEntryService.todayString(),
                doneValue: doneValue,
                note: existing?.note,
                tags: existing?.tags ?? [],
                breakContext: existing?.breakContext,
                privacyTier: habit.direction == .reduce ? .sensitive : .normal
            )
            do {
                try await LogEntryService.upsert(input)
                await load()
            } catch {
                status = "Couldn't save: \(error.localizedDescription)"
            }
        }
    }

    private func toggleDone(_ habit: Habit) {
        if state(for: habit) == .done {
            clearLog(habit)
        } else {
            setDone(habit, doneValue: 1)
        }
    }

    private func markNotDone(_ habit: Habit) {
        setDone(habit, doneValue: 0)
    }

    private func clearLog(_ habit: Habit) {
        Task {
            do {
                try await LogEntryService.clear(habitId: habit.id)
                logEntries.removeValue(forKey: habit.id)
            } catch {
                status = "Couldn't clear: \(error.localizedDescription)"
            }
        }
    }

    private func openDetail(_ habit: Habit) {
        let existing = logEntries[habit.id]
        detailNote = existing?.note ?? ""
        detailTags = existing?.tags ?? []
        detailBreakContext = existing?.breakContext ?? ""
        detailHabit = habit
    }

    private func saveDetail(_ habit: Habit) {
        Task {
            do {
                var resolvedTags: [String] = []
                for tag in detailTags {
                    resolvedTags.append((try await TagService.resolve(tag)).display)
                }
                let existing = logEntries[habit.id]
                let input = LogEntryService.LogEntryInput(
                    habitId: habit.id,
                    date: LogEntryService.todayString(),
                    doneValue: existing?.doneValue ?? 0,
                    note: detailNote.isEmpty ? nil : detailNote,
                    tags: resolvedTags,
                    breakContext: detailBreakContext.isEmpty ? nil : detailBreakContext,
                    privacyTier: habit.direction == .reduce ? .sensitive : .normal
                )
                try await LogEntryService.upsert(input)
                await load()
            } catch {
                status = "Couldn't save: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    HomeView()
}
