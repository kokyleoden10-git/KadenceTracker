import SwiftUI

/// Habit management (spec §8 step 3) — everything, regardless of today's
/// schedule. Deliberately separate from HomeView (step 2, the daily log
/// surface, today-only) rather than conflated into one screen.
struct ManageHabitsView: View {
    private enum Scope: String, CaseIterable {
        case active = "Active"
        case archived = "Archived"
    }

    @State private var scope: Scope = .active
    @State private var activeHabits: [Habit] = []
    @State private var archivedHabits: [Habit] = []
    @State private var status = "Loading\u{2026}"
    @State private var formMode: HabitFormView.Mode?
    @Environment(\.dismiss) private var dismiss

    private var visibleHabits: [Habit] {
        scope == .active ? activeHabits : archivedHabits
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KadenceTheme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Picker("Scope", selection: $scope) {
                            ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        if visibleHabits.isEmpty && status.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 8) {
                                ForEach(visibleHabits) { habit in
                                    HabitRow(
                                        habit: habit,
                                        action: { formMode = .edit(habit) },
                                        unarchiveAction: scope == .archived ? { unarchive(habit) } : nil
                                    )
                                }
                            }
                        }

                        if !status.isEmpty {
                            Text(status)
                                .font(KadenceTheme.bodyFont(13))
                                .foregroundStyle(KadenceTheme.textMuted)
                        }
                    }
                    .padding()
                }
                .refreshable { await load() }
            }
            .navigationTitle("Manage Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        formMode = .create
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(KadenceTheme.piscesTeal)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(KadenceTheme.textMuted)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        .sheet(item: $formMode) { mode in
            HabitFormView(mode: mode) {
                Task { await load() }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            if scope == .active {
                Text("No habits yet.")
                    .font(KadenceTheme.bodyFont(15))
                    .foregroundStyle(KadenceTheme.textMuted)

                Button {
                    formMode = .create
                } label: {
                    Text("Add your first habit")
                        .font(KadenceTheme.bodyFontSemibold(15))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .background(KadenceTheme.piscesTeal)
                .foregroundStyle(KadenceTheme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("No archived habits.")
                    .font(KadenceTheme.bodyFont(15))
                    .foregroundStyle(KadenceTheme.textMuted)
            }
        }
    }

    private func load() async {
        do {
            async let activeTask = HabitService.fetchActive()
            async let archivedTask = HabitService.fetchArchived()
            activeHabits = try await activeTask
            archivedHabits = try await archivedTask
            status = ""
        } catch {
            status = "Couldn't load: \(error.localizedDescription)"
        }
    }

    private func unarchive(_ habit: Habit) {
        Task {
            do {
                try await HabitService.unarchive(habit.id)
                await load()
            } catch {
                status = "Couldn't restore: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ManageHabitsView()
}
