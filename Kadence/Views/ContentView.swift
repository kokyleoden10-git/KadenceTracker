import SwiftUI

/// Smoke-test screen: confirms the app can reach Supabase and read the
/// `habit` table. Replace with the real daily-log screen (spec §8, step 2).
struct ContentView: View {
    @State private var habits: [Habit] = []
    @State private var status: String = "Loading…"

    var body: some View {
        ZStack {
            KadenceTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Kadence")
                    .font(KadenceTheme.displayFont(34))
                    .foregroundStyle(KadenceTheme.text)

                Text(status)
                    .font(KadenceTheme.bodyFont())
                    .foregroundStyle(KadenceTheme.text.opacity(0.7))

                ForEach(habits) { habit in
                    HStack {
                        Circle()
                            .fill(KadenceTheme.color(for: habit.domain))
                            .frame(width: 10, height: 10)
                        Text(habit.name)
                            .foregroundStyle(KadenceTheme.text)
                    }
                }
            }
            .padding()
        }
        .task {
            do {
                habits = try await SupabaseService.shared.fetchHabits()
                status = habits.isEmpty
                    ? "Connected to Supabase — no habits yet."
                    : "Connected to Supabase — \(habits.count) habit(s)."
            } catch {
                status = "Supabase connection failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ContentView()
}
