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
                AuthGatedView { HomeView() }
                    .tabItem { Label("Today", systemImage: "house.fill") }

                AuthGatedView { DrawView() }
                    .tabItem { Label("Draw", systemImage: "sparkles") }

                AuthGatedView { TidesView() }
                    .tabItem { Label("Tides", systemImage: "water.waves") }

                AuthGatedView { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .tint(KadenceTheme.piscesTeal)
        }
    }
}

/// Every tab needs a session now. Draw used to be exempt while its data
/// was local-only; moving the card log to Supabase means it needs a
/// user_id like everything else, so the exemption is gone.
private struct AuthGatedView<Content: View>: View {
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
