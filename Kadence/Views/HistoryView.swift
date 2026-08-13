import SwiftUI

/// Reverse-chronological list of past days. Draw only ever shows today,
/// and Tides only shows the aggregate shape across the lunar cycle — this
/// is the one place to catch a missed reflection window and go back to it,
/// which is a deliberate loosening of the "same day" ritual: a missed 8pm
/// shouldn't mean that day's reflection is gone forever.
///
/// A list rather than a calendar grid — with one entry a day at most,
/// scanning a reverse list surfaces "what's unfinished" immediately, and a
/// grid's spatial month layout doesn't earn its complexity until there's
/// enough history that scrolling a list gets old.
struct HistoryView: View {
    @State private var entries: [EntryWithDraws] = []
    @State private var status = "Loading\u{2026}"
    @State private var reflectingEntry: EntryWithDraws?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if !status.isEmpty {
                        Text(status)
                            .font(KadenceTheme.bodyFont(14))
                            .foregroundStyle(KadenceTheme.textMuted)
                    } else if entries.isEmpty {
                        Text("Nothing logged yet.")
                            .font(KadenceTheme.bodyFont(14))
                            .foregroundStyle(KadenceTheme.textMuted)
                    } else {
                        ForEach(entries) { entry in
                            row(entry)
                        }
                    }
                }
                .padding()
            }
            .background(KadenceTheme.bg.ignoresSafeArea())
            .refreshable { await load() }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        .sheet(item: $reflectingEntry, onDismiss: { Task { await load() } }) { entry in
            PastReflectionSheet(entry: entry)
        }
    }

    private func row(_ entry: EntryWithDraws) -> some View {
        let needsReflection = isNeedingReflection(entry)

        let content = HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateLabel(entry.entry.date))
                    .font(KadenceTheme.bodyFontSemibold(13))
                    .foregroundStyle(KadenceTheme.textPrimary)
                Text(subtitle(entry))
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            statusBadge(entry, needsReflection: needsReflection)
        }
        .padding(12)
        .background(KadenceTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))

        return Group {
            if needsReflection {
                Button {
                    reflectingEntry = entry
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private func isNeedingReflection(_ entry: EntryWithDraws) -> Bool {
        !entry.entry.skipped
            && entry.dailyDraw != nil
            && (entry.entry.eveningReflection?.isEmpty ?? true)
    }

    private func subtitle(_ entry: EntryWithDraws) -> String {
        if entry.entry.skipped { return "No pull" }
        guard let daily = entry.dailyDraw else { return "\u{2014}" }
        var parts = [daily.cardName]
        if daily.reversed { parts.append("reversed") }
        if !entry.jumperDraws.isEmpty {
            parts.append(entry.jumperDraws.count == 1 ? "1 jumper" : "\(entry.jumperDraws.count) jumpers")
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func statusBadge(_ entry: EntryWithDraws, needsReflection: Bool) -> some View {
        Group {
            if entry.entry.skipped {
                Text("\u{2014}")
                    .foregroundStyle(KadenceTheme.textMuted)
            } else if needsReflection {
                Text("Reflect")
                    .foregroundStyle(KadenceTheme.piscesTeal)
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(KadenceTheme.textMuted)
            }
        }
        .font(KadenceTheme.bodyFontSemibold(12))
    }

    private func load() async {
        do {
            entries = try await EntryService.fetchAll()
            status = ""
        } catch is CancellationError {
            // Superseded by a newer load — not a real failure.
        } catch {
            status = "Couldn't load: \(error.localizedDescription)"
        }
    }

    static func dateLabel(_ dateString: String) -> String {
        guard let date = SupabaseDate.date(dateString) else { return dateString }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

/// Reflecting on a day after the fact — same question DrawView asks in the
/// evening ("what happened, does it read differently now?"), just reached
/// from History instead of from today's ritual.
private struct PastReflectionSheet: View {
    let entry: EntryWithDraws

    @Environment(\.dismiss) private var dismiss
    @State private var reflection = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.dailyDraw?.cardName ?? "")
                        .font(KadenceTheme.displayFont(22))
                        .foregroundStyle(KadenceTheme.textPrimary)
                    if entry.dailyDraw?.reversed == true {
                        Text("Reversed")
                            .font(KadenceTheme.bodyFont(12))
                            .foregroundStyle(KadenceTheme.textMuted)
                    }
                    if let attribution = entry.dailyDraw?.card?.attributionLine {
                        Text(attribution)
                            .font(KadenceTheme.bodyFont(12))
                            .foregroundStyle(KadenceTheme.textMuted)
                            .padding(.top, 2)
                    }
                    if let line = entry.entry.morningRead, !line.isEmpty {
                        Text("\u{201C}\(line)\u{201D}")
                            .font(KadenceTheme.bodyFont(14))
                            .italic()
                            .foregroundStyle(KadenceTheme.piscesSeafoam.opacity(0.9))
                            .padding(.top, 4)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KadenceTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("What happened? Does it read differently now?")
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.textMuted)
                    TextField("Reflection", text: $reflection, axis: .vertical)
                        .padding(10)
                        .background(KadenceTheme.surface)
                        .foregroundStyle(KadenceTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.ariesEmber)
                }

                Spacer()

                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .background(KadenceTheme.piscesTeal)
                .foregroundStyle(KadenceTheme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(isSaving)
            }
            .padding()
            .background(KadenceTheme.bg.ignoresSafeArea())
            .navigationTitle(HistoryView.dateLabel(entry.entry.date))
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

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await EntryService.patch(entry.entry, eveningReflection: reflection.isEmpty ? nil : reflection)
            dismiss()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

#Preview {
    HistoryView()
}
