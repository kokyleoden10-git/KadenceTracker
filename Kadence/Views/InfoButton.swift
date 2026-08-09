import SwiftUI

/// Small "i" affordance that reveals a short explanation on tap — used next
/// to profile fields whose purpose isn't self-evident (why does this app
/// want my birth time?).
///
/// Uses .alert rather than .popover: popover sizing/truncation turned out
/// to behave differently depending on presentation context (plain screen
/// vs. already inside a .sheet), and got clipped in the latter even with
/// fixedSize applied. Alerts always auto-size to their full text regardless
/// of what's presenting them, at the cost of the little pointer-arrow
/// affordance popovers have.
struct InfoButton: View {
    let text: String
    @State private var isShowingInfo = false

    var body: some View {
        Button {
            isShowingInfo = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(KadenceTheme.textMuted)
        }
        .alert("", isPresented: $isShowingInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(text)
        }
    }
}
