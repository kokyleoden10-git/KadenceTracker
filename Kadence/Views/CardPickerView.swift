import SwiftUI

/// Structured picker rather than free text — needed so resonance can look
/// the card up in the catalog. Names shown respect the deck's tradition
/// (a Thoth deck shows "Knight of Cups", an RWS deck shows "King of Cups"
/// for the same underlying card).
struct CardPickerView: View {
    let tradition: Tradition
    var onPick: (TarotCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [TarotCard] {
        guard !query.isEmpty else { return CardCatalog.all }
        return CardCatalog.all.filter {
            $0.name(for: tradition).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { card in
                Button {
                    onPick(card)
                    dismiss()
                } label: {
                    Text(card.name(for: tradition))
                        .font(KadenceTheme.bodyFont(15))
                        .foregroundStyle(KadenceTheme.textPrimary)
                }
                .listRowBackground(KadenceTheme.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(KadenceTheme.bg.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search 78 cards")
            .navigationTitle("Which card?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(KadenceTheme.textMuted)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
