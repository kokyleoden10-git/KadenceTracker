import SwiftUI

/// Minimal by design — v3 spec Step 1 doesn't have a card catalog yet
/// (that's resonance-engine territory, Step 3), so a deck is just a name,
/// tradition, and whether it uses reversals. Rank-naming translation
/// (Thoth Knight = RWS King) only matters once a catalog exists to
/// translate against.
struct DeckFormView: View {
    var onSaved: (RemoteDeck) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var tradition: Tradition = .rws
    @State private var usesReversals = true
    @State private var isSaving = false
    @State private var status: String?

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deck name")
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.textMuted)
                    TextField("e.g. My Thoth deck", text: $name)
                        .padding(10)
                        .background(KadenceTheme.surface)
                        .foregroundStyle(KadenceTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tradition")
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.textMuted)
                    Picker("Tradition", selection: $tradition) {
                        ForEach(Tradition.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Toggle(isOn: $usesReversals) {
                    Text("Uses reversals")
                        .font(KadenceTheme.bodyFont(14))
                        .foregroundStyle(KadenceTheme.textPrimary)
                }
                .tint(KadenceTheme.piscesTeal)

                Spacer()

                Button("Add Deck") {
                    Task {
                        isSaving = true
                        defer { isSaving = false }
                        do {
                            let deck = try await DeckService.create(
                                name: name.trimmingCharacters(in: .whitespaces),
                                tradition: tradition,
                                usesReversals: usesReversals
                            )
                            onSaved(deck)
                            dismiss()
                        } catch {
                            status = "Couldn't add deck: \(error.localizedDescription)"
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isValid ? KadenceTheme.piscesTeal : KadenceTheme.surface)
                .foregroundStyle(isValid ? KadenceTheme.bg : KadenceTheme.textMuted)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!isValid || isSaving)

                if let status {
                    Text(status)
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.ariesEmber)
                }
            }
            .padding()
            .background(KadenceTheme.bg.ignoresSafeArea())
            .navigationTitle("New Deck")
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

#Preview {
    DeckFormView(onSaved: { _ in })
}
