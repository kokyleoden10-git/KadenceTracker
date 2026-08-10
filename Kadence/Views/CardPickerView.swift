import SwiftUI

/// Structured picker rather than free text — resonance needs a catalog
/// match, not a string. Names respect the deck's tradition (a Thoth deck
/// shows "Knight of Cups", an RWS deck "King of Cups" for the same card).
///
/// Two layout rules that matter for one-handed use: the search field sits
/// at the bottom under the thumb, and results stack up *from* it rather
/// than filling from the top. A single match therefore appears right above
/// the field instead of stranded at the top of an otherwise empty screen.
/// The unfiltered list still opens full-height and top-anchored, since
/// browsing all 78 wants the opposite treatment.
struct CardPickerView: View {
    let tradition: Tradition
    var onPick: (TarotCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var results: [TarotCard] {
        CardCatalog.search(query, tradition: tradition)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                resultsList
                searchField
            }
            .background(KadenceTheme.bg.ignoresSafeArea())
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

    private var resultsList: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Pushes short result sets down to sit against the
                    // search field; inert once content exceeds the viewport.
                    Spacer(minLength: 0)

                    if results.isEmpty {
                        Text("No cards match that.")
                            .font(KadenceTheme.bodyFont(14))
                            .foregroundStyle(KadenceTheme.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }

                    ForEach(CardCatalog.grouped(results), id: \.section.id) { group in
                        Text(group.section.rawValue.uppercased())
                            .font(KadenceTheme.bodyFontSemibold(11))
                            .tracking(1)
                            .foregroundStyle(KadenceTheme.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 6)

                        ForEach(group.cards) { card in
                            Button {
                                onPick(card)
                                dismiss()
                            } label: {
                                row(card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(minHeight: proxy.size.height, alignment: .bottom)
            }
            .defaultScrollAnchor(isSearching ? .bottom : .top)
        }
    }

    private func row(_ card: TarotCard) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.name(for: tradition))
                .font(KadenceTheme.bodyFont(16))
                .foregroundStyle(KadenceTheme.textPrimary)
            if let attribution = attribution(for: card) {
                Text(attribution)
                    .font(KadenceTheme.bodyFont(11))
                    .foregroundStyle(KadenceTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    /// Spec's Tier 1 — attribution is fact, not interpretation, and is
    /// explicitly never meant to be hidden.
    private func attribution(for card: TarotCard) -> String? {
        var parts: [String] = []
        parts += card.signs.map(\.displayName)
        parts += card.planets.map(\.displayName)
        if let element = card.element ?? card.signs.first.map(element(of:)) {
            parts.append(element.displayName)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(KadenceTheme.textMuted)
            TextField("Search by name, number, sign, element", text: $query)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(KadenceTheme.textPrimary)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KadenceTheme.textMuted)
                }
            }
        }
        .padding(12)
        .background(KadenceTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#Preview {
    CardPickerView(tradition: .rws) { _ in }
}
