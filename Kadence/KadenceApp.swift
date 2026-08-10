import SwiftData
import SwiftUI

@main
struct KadenceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Deck.self, Entry.self, Draw.self])
    }
}
