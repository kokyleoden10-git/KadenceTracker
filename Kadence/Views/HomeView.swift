import SwiftUI

/// Smoke-test screen: confirms auth + Supabase wiring end to end. Replace
/// the habit list with the real daily-log screen (spec §8, step 2).
struct HomeView: View {
    @State private var habits: [Habit] = []
    @State private var profile: Profile?
    @State private var status = "Loading\u{2026}"

    var body: some View {
        ZStack {
            KadenceTheme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeHeaderView(profile: profile)

                    Text(status)
                        .font(KadenceTheme.bodyFont())
                        .foregroundStyle(KadenceTheme.textMuted)

                    ForEach(habits) { habit in
                        HStack {
                            Circle()
                                .fill(KadenceTheme.color(for: habit.domain))
                                .frame(width: 10, height: 10)
                            Text(habit.name)
                                .foregroundStyle(KadenceTheme.textPrimary)
                        }
                    }

                    Button("Sign out") {
                        Task { try? await AuthService.shared.signOut() }
                    }
                    .font(KadenceTheme.bodyFont(13))
                    .foregroundStyle(KadenceTheme.textMuted)
                    .padding(.top, 24)
                }
                .padding()
            }
        }
        .task {
            do {
                async let profileTask = ProfileService.fetchCurrent()
                async let habitsTask = SupabaseService.shared.fetchHabits()
                profile = try await profileTask
                habits = try await habitsTask
                status = habits.isEmpty ? "No habits yet." : "\(habits.count) habit(s)."
            } catch {
                status = "Couldn't load data: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    HomeView()
}
