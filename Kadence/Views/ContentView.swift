import SwiftUI

struct ContentView: View {
    @ObservedObject private var auth = AuthService.shared

    var body: some View {
        ZStack {
            KadenceTheme.bg.ignoresSafeArea()

            if auth.isLoading {
                ProgressView()
                    .tint(KadenceTheme.textPrimary)
            } else if auth.session != nil {
                HomeView()
            } else {
                SignInView()
            }
        }
    }
}

#Preview {
    ContentView()
}
