import SwiftUI

/// Habit management (spec §8 step 3) — explicitly called out in the spec as
/// "the screen most likely to trigger perfectionist paralysis, so favor
/// sensible defaults over exhaustive config." That's why identity
/// statement/stack cue are collapsed behind an optional disclosure instead
/// of sitting in the primary flow, Anchors skip the days-active picker
/// entirely (they're always daily per spec), and a brand-new Practice
/// defaults to every day active rather than starting from zero.
struct HabitFormView: View {
    enum Mode: Identifiable {
        case create
        case edit(Habit)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let habit): return habit.id.uuidString
            }
        }
    }

    let mode: Mode
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var domain: Domain = .wellbeing
    @State private var tier: Tier = .anchor
    @State private var direction: Direction = .build
    @State private var daysActive: Set<Int> = Set(0...6)
    @State private var identityStatement = ""
    @State private var stackCue = ""
    @State private var showOptionalDetails = false

    @State private var isSaving = false
    @State private var isArchiving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var isConfirmingArchive = false
    @State private var isConfirmingDelete = false

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (tier == .anchor || !daysActive.isEmpty)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameField
                    domainPicker
                    tierPicker
                    directionPicker
                    if tier == .practice {
                        daysActivePicker
                    }
                    optionalDetails

                    if let errorMessage {
                        Text(errorMessage)
                            .font(KadenceTheme.bodyFont(12))
                            .foregroundStyle(KadenceTheme.ariesEmber)
                    }

                    saveButton

                    if case .edit(let habit) = mode {
                        archiveButton(habit)
                        deleteButton(habit)
                    }
                }
                .padding()
            }
            .background(KadenceTheme.bg.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(KadenceTheme.textMuted)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: populateIfEditing)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name")
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
            TextField("e.g. Meditate", text: $name)
                .padding(10)
                .background(KadenceTheme.surface)
                .foregroundStyle(KadenceTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var domainPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Domain")
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Domain.allCases, id: \.self) { option in
                    let isSelected = domain == option
                    let color = KadenceTheme.color(for: option)
                    Button {
                        domain = option
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)
                            Text(option.rawValue.capitalized)
                                .font(KadenceTheme.bodyFontSemibold(14))
                                .foregroundStyle(KadenceTheme.textPrimary)
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? color.opacity(0.22) : KadenceTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? color : .clear, lineWidth: 1.5)
                        )
                    }
                }
            }
        }
    }

    private var tierPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Tier")
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
                InfoButton(text: "Anchors are small and daily — two minutes, tops. Practices are deeper and only happen on the days you choose.")
            }
            Picker("Tier", selection: $tier) {
                Text("Anchor").tag(Tier.anchor)
                Text("Practice").tag(Tier.practice)
            }
            .pickerStyle(.segmented)
            .onChange(of: tier) { _, newValue in
                if newValue == .anchor {
                    daysActive = Set(0...6)
                }
            }
        }
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Direction")
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
                InfoButton(text: "Build habits you're adding. Reduce is for things you're cutting back on — tracked honestly as their own kind, never silently excluded.")
            }
            Picker("Direction", selection: $direction) {
                Text("Build").tag(Direction.build)
                Text("Reduce").tag(Direction.reduce)
            }
            .pickerStyle(.segmented)
        }
    }

    private var daysActivePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active days")
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { day in
                    let isOn = daysActive.contains(day)
                    Button {
                        if isOn { daysActive.remove(day) } else { daysActive.insert(day) }
                    } label: {
                        Text(dayLabels[day])
                            .font(KadenceTheme.bodyFontSemibold(13))
                            .frame(width: 34, height: 34)
                            .background(isOn ? KadenceTheme.color(for: domain) : KadenceTheme.surface)
                            .foregroundStyle(isOn ? KadenceTheme.bg : KadenceTheme.textMuted)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var optionalDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { showOptionalDetails.toggle() }
            } label: {
                HStack {
                    Text("Identity & cue (optional)")
                        .font(KadenceTheme.bodyFont(13))
                        .foregroundStyle(KadenceTheme.piscesTeal)
                    Image(systemName: showOptionalDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(KadenceTheme.piscesTeal)
                }
            }

            if showOptionalDetails {
                VStack(alignment: .leading, spacing: 12) {
                    labeledOptionalField("Identity statement", placeholder: "I am someone who...", text: $identityStatement)
                    labeledOptionalField("Stack cue", placeholder: "After I..., I will...", text: $stackCue)
                }
            }
        }
    }

    private func labeledOptionalField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
            TextField(placeholder, text: text)
                .padding(10)
                .background(KadenceTheme.surface)
                .foregroundStyle(KadenceTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Group {
                if isSaving {
                    ProgressView()
                } else {
                    Text(isEditing ? "Save Changes" : "Add Habit")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .background(isValid ? KadenceTheme.color(for: domain) : KadenceTheme.surface)
        .foregroundStyle(isValid ? KadenceTheme.bg : KadenceTheme.textMuted)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .disabled(!isValid || isSaving)
    }

    private func archiveButton(_ habit: Habit) -> some View {
        Button("Archive Habit") {
            isConfirmingArchive = true
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(KadenceTheme.ariesEmber)
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(KadenceTheme.ariesEmber.opacity(0.4), lineWidth: 1)
        )
        .disabled(isArchiving)
        .confirmationDialog(
            "This stops \"\(habit.name)\" from showing up going forward. Past log history is kept, not deleted.",
            isPresented: $isConfirmingArchive,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) {
                Task { await archive(habit) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Deliberately styled more severely than Archive (solid fill vs.
    /// outline) — this is a real hard delete, an explicit exception to
    /// spec §5's "never hard-delete" default, added on request. It also
    /// cascades to permanently destroy every logged entry for this habit,
    /// not just the habit definition, so the confirmation says that
    /// explicitly rather than a generic "can't be undone."
    private func deleteButton(_ habit: Habit) -> some View {
        Button("Delete Habit Permanently") {
            isConfirmingDelete = true
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(KadenceTheme.ariesEmber)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .disabled(isDeleting)
        .confirmationDialog(
            "This permanently deletes \"\(habit.name)\" and every day you've ever logged for it. This cannot be undone — there is no backup copy kept.",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Forever", role: .destructive) {
                Task { await delete(habit) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func populateIfEditing() {
        guard case .edit(let habit) = mode else { return }
        name = habit.name
        domain = habit.domain
        tier = habit.tier
        direction = habit.direction
        daysActive = Set(habit.daysActive)
        identityStatement = habit.identityStatement ?? ""
        stackCue = habit.stackCue ?? ""
        showOptionalDetails = !identityStatement.isEmpty || !stackCue.isEmpty
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            let input = HabitService.HabitInput(
                name: name.trimmingCharacters(in: .whitespaces),
                domain: domain,
                tier: tier,
                direction: direction,
                daysActive: tier == .anchor ? Array(0...6) : Array(daysActive).sorted(),
                identityStatement: identityStatement.isEmpty ? nil : identityStatement,
                stackCue: stackCue.isEmpty ? nil : stackCue
            )
            do {
                switch mode {
                case .create:
                    try await HabitService.create(input)
                case .edit(let habit):
                    try await HabitService.update(habit.id, with: input)
                }
                onSaved()
                dismiss()
            } catch {
                errorMessage = "Couldn't save: \(error.localizedDescription)"
            }
        }
    }

    private func archive(_ habit: Habit) async {
        isArchiving = true
        defer { isArchiving = false }
        do {
            try await HabitService.archive(habit.id)
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Couldn't archive: \(error.localizedDescription)"
        }
    }

    private func delete(_ habit: Habit) async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await HabitService.delete(habit.id)
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Couldn't delete: \(error.localizedDescription)"
        }
    }
}

#Preview {
    HabitFormView(mode: .create, onSaved: {})
}
