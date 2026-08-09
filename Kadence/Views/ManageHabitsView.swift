import SwiftUI

/// Habit management (spec §8 step 3) — everything, regardless of today's
/// schedule. Deliberately separate from HomeView (step 2, the daily log
/// surface, today-only) rather than conflated into one screen.
struct ManageHabitsView: View {
    @State private var habits: [Habit] = []
    @State private var status = "Loading\u{2026}"
    @State private var formMode: HabitFormView.Mode?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                KadenceTheme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if habits.isEmpty && status.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 8) {
                                ForEach(habits) { habit in
                                    HabitRow(habit: habit) {
                                        formMode = .edit(habit)
                                    }
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
        }
    }

    private func load() async {
        do {
            habits = try await HabitService.fetchActive()
            status = ""
        } catch {
            status = "Couldn't load: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ManageHabitsView()
}
