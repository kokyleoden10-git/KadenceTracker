import SwiftUI

/// Optional secondary surface — the primary daily interaction is the
/// checkbox tap in DailyHabitRow; this is for the "log fast" philosophy's
/// occasional deeper moment (a note, tags, or the break_context prompt),
/// never required to complete a habit for the day.
struct LogDetailSheet: View {
    let habit: Habit
    let showBreakContext: Bool
    @Binding var note: String
    @Binding var tags: [String]
    @Binding var breakContext: String
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tagInput = ""
    @State private var suggestions: [Tag] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(habit.name)
                        .font(KadenceTheme.displayFont(22))
                        .foregroundStyle(KadenceTheme.textPrimary)

                    if showBreakContext {
                        labeledField("What happened right before? (optional)", text: $breakContext)
                    }

                    labeledField("Note (optional)", text: $note)

                    tagSection

                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(KadenceTheme.color(for: habit.domain))
                    .foregroundStyle(KadenceTheme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .background(KadenceTheme.bg.ignoresSafeArea())
            .navigationTitle("Log Detail")
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

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
            TextField("", text: text, axis: .vertical)
                .padding(10)
                .background(KadenceTheme.surface)
                .foregroundStyle(KadenceTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags (up to 3)")
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)

            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .font(KadenceTheme.bodyFont(12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(KadenceTheme.piscesSeafoam.opacity(0.2))
                        .foregroundStyle(KadenceTheme.textPrimary)
                        .clipShape(Capsule())
                    }
                }
            }

            if tags.count < 3 {
                TextField("Add a tag", text: $tagInput)
                    .padding(10)
                    .background(KadenceTheme.surface)
                    .foregroundStyle(KadenceTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: tagInput) { _, newValue in
                        Task { suggestions = (try? await TagService.suggestions(matching: newValue)) ?? [] }
                    }
                    .onSubmit {
                        addTag(tagInput)
                    }

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions) { tag in
                            Button {
                                addTag(tag.display)
                            } label: {
                                Text(tag.display)
                                    .font(KadenceTheme.bodyFont(13))
                                    .foregroundStyle(KadenceTheme.textPrimary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .background(KadenceTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func addTag(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              tags.count < 3,
              !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return }
        tags.append(trimmed)
        tagInput = ""
        suggestions = []
    }
}
