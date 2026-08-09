import MapKit
import SwiftUI

/// Location autocomplete backed by MapKit's on-device completer — no API
/// key, no third-party service, consistent with the rest of the app's
/// "no external credential" stance (weather is the one deliberate
/// exception, and that's clearly labeled).
struct LocationSearchField: View {
    let label: String
    @Binding var text: String
    var infoText: String? = nil

    @StateObject private var completer = LocationCompleter()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
                if let infoText {
                    InfoButton(text: infoText)
                }
            }

            HStack(spacing: 8) {
                TextField(label, text: $text)
                    .focused($isFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                if !text.isEmpty {
                    Button {
                        text = ""
                        completer.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(KadenceTheme.textMuted)
                    }
                }
            }
            .padding(10)
            .background(KadenceTheme.surface)
            .foregroundStyle(KadenceTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: text) { _, newValue in
                completer.update(query: newValue)
            }

            if isFocused, !completer.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(completer.results.enumerated()), id: \.offset) { index, result in
                        Button {
                            text = result.subtitle.isEmpty ? result.title : "\(result.title), \(result.subtitle)"
                            completer.results = []
                            isFocused = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(KadenceTheme.bodyFont(14))
                                    .foregroundStyle(KadenceTheme.textPrimary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(KadenceTheme.bodyFont(11))
                                        .foregroundStyle(KadenceTheme.textMuted)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if index != completer.results.count - 1 {
                            Divider().overlay(KadenceTheme.textMuted.opacity(0.2))
                        }
                    }
                }
                .background(KadenceTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

@MainActor
private final class LocationCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
    }

    func update(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let newResults = completer.results
        Task { @MainActor in
            self.results = newResults
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Autocomplete failing isn't fatal — the field still works as plain text entry.
    }
}
