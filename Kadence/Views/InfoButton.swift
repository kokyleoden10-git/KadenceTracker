import SwiftUI

/// Small "i" affordance that reveals a short explanation on tap — used next
/// to profile fields whose purpose isn't self-evident (why does this app
/// want my birth time?).
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
        .popover(isPresented: $isShowingInfo) {
            Text(text)
                .font(KadenceTheme.bodyFont(13))
                .foregroundStyle(KadenceTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .frame(maxWidth: 260)
                .background(KadenceTheme.surface)
                .presentationCompactAdaptation(.popover)
        }
    }
}
