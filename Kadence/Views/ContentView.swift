import SwiftUI

struct ContentView: View {
    @ObservedObject private var auth = AuthService.shared

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

            if auth.isLoading {
                ProgressView()
                    .tint(KadenceTheme.textPrimary)
            } else if auth.session != nil {
                TabView {
                    HomeView()
                        .tabItem { Label("Today", systemImage: "house.fill") }

                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                }
                .tint(KadenceTheme.piscesTeal)
            } else {
                SignInView()
            }
        }
    }
}

#Preview {
    ContentView()
}
