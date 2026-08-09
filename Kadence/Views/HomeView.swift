import SwiftUI

struct HomeView: View {
    @State private var habits: [Habit] = []
    @State private var profile: Profile?
    @State private var status = "Loading\u{2026}"
    @State private var formMode: HabitFormView.Mode?

    var body: some View {
        NavigationStack {
            ZStack {
                KadenceTheme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HomeHeaderView(profile: profile, status: status)

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
                    }
                    .padding()
                }
                .refreshable { await load() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        formMode = .create
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(KadenceTheme.piscesTeal)
                    }
                }
            }
        }
        .task { await load() }
        .sheet(item: $formMode) { mode in
            HabitFormView(mode: mode) {
                Task { await load() }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing tracked yet.")
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
            async let profileTask = ProfileService.fetchCurrent()
            async let habitsTask = HabitService.fetchActive()
            profile = try await profileTask
            habits = try await habitsTask
            status = ""
        } catch {
            status = "Couldn't load data: \(error.localizedDescription)"
        }
    }
}

#Preview {
    HomeView()
}
