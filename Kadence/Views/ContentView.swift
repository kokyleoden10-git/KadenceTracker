import SwiftUI

struct ContentView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(KadenceTheme.surface)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            KadenceTheme.bg.ignoresSafeArea()

            TabView {
                DrawView()
                    .tabItem { Label("Draw", systemImage: "sparkles") }

                HabitsGatedView { HomeView() }
                    .tabItem { Label("Today", systemImage: "house.fill") }

                HabitsGatedView { TidesView() }
                    .tabItem { Label("Tides", systemImage: "water.waves") }

                HabitsGatedView { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .tint(KadenceTheme.piscesTeal)
        }
    }
}

/// Habit tracking (Today/Settings) still requires Supabase auth. Draw
/// (v3 spec Step 1) deliberately doesn't — it's local-only for now, and
/// bypassing sign-in there is temporary, to prove the daily card log
/// survives a week before anything gets wired back up to an account.
private struct HabitsGatedView<Content: View>: View {
    @ObservedObject private var auth = AuthService.shared
    @ViewBuilder var content: () -> Content

    var body: some View {
        if auth.isLoading {
            ProgressView()
                .tint(KadenceTheme.textPrimary)
        } else if auth.session != nil {
            content()
        } else {
            SignInView()
        }
    }
}

#Preview {
    ContentView()
}
