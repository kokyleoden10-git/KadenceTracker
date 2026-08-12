import SwiftUI

/// Habit management (spec §8 step 3) — everything, regardless of today's
/// schedule. Deliberately separate from HomeView (step 2, the daily log
/// surface, today-only) rather than conflated into one screen.
struct ManageHabitsView: View {
    private enum Scope: String, CaseIterable {
        case active = "Active"
        case archived = "Archived"
    }

    @State private var scope: Scope = .active
    @State private var activeHabits: [Habit] = []
    @State private var archivedHabits: [Habit] = []
    @State private var status = "Loading\u{2026}"
    @State private var formMode: HabitFormView.Mode?
    @Environment(\.dismiss) private var dismiss

    @AppStorage("permanentDeletionEnabled") private var permanentDeletionEnabled = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var isConfirmingBulkArchive = false
    @State private var isConfirmingBulkDelete = false
    @State private var isBulkActing = false

    private var visibleHabits: [Habit] {
        scope == .active ? activeHabits : archivedHabits
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KadenceTheme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Picker("Scope", selection: $scope) {
                            ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: scope) { _, _ in selectedIDs = [] }

                        selectionActionBar

                        if visibleHabits.isEmpty && status.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 8) {
                                ForEach(visibleHabits) { habit in
                                    if isSelecting {
                                        selectableRow(habit)
                                    } else {
                                        HabitRow(
                                            habit: habit,
                                            action: { formMode = .edit(habit) },
                                            unarchiveAction: scope == .archived ? { unarchive(habit) } : nil
                                        )
                                    }
                                }
                            }
                        }

                        if !status.isEmpty {
                            Text(status)
                                .font(KadenceTheme.bodyFont(13))
                                .foregroundStyle(KadenceTheme.textMuted)
                        }
                    }
                    .padding()
                }
                .refreshable { await load() }
            }
            .navigationTitle("Manage Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isSelecting ? "Cancel" : "Done") {
                        if isSelecting {
                            isSelecting = false
                            selectedIDs = []
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(KadenceTheme.textMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !isSelecting {
                        HStack(spacing: 16) {
                            if !visibleHabits.isEmpty {
                                Button("Select") { isSelecting = true }
                                    .foregroundStyle(KadenceTheme.piscesTeal)
                            }
                            Button {
                                formMode = .create
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(KadenceTheme.piscesTeal)
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        .sheet(item: $formMode) { mode in
            HabitFormView(mode: mode) {
                Task { await load() }
            }
        }
        .confirmationDialog(
            "Archive \(selectedIDs.count) habit\(selectedIDs.count == 1 ? "" : "s")? \(selectedIDs.count == 1 ? "It" : "They") will stop showing up, but past log history is kept, not deleted.",
            isPresented: $isConfirmingBulkArchive,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) { Task { await bulkArchive() } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Permanently delete \(selectedIDs.count) habit\(selectedIDs.count == 1 ? "" : "s") and every entry ever logged for \(selectedIDs.count == 1 ? "it" : "them")? This cannot be undone.",
            isPresented: $isConfirmingBulkDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Forever", role: .destructive) { Task { await bulkDelete() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// A lighter row than HabitRow for selection mode — a leading checkbox
    /// in place of the chevron/restore affordance, and tapping anywhere
    /// toggles selection instead of opening the edit form.
    private func selectableRow(_ habit: Habit) -> some View {
        let isSelected = selectedIDs.contains(habit.id)
        return Button {
            if isSelected { selectedIDs.remove(habit.id) } else { selectedIDs.insert(habit.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? KadenceTheme.piscesTeal : KadenceTheme.textMuted)
                Circle()
                    .fill(KadenceTheme.color(for: habit.domain))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(KadenceTheme.bodyFont(15))
                        .foregroundStyle(KadenceTheme.textPrimary)
                    Text(habit.tier == .anchor ? "Anchor" : "Practice")
                        .font(KadenceTheme.bodyFont(11))
                        .foregroundStyle(KadenceTheme.textMuted)
                }
                Spacer()
            }
            .padding(12)
            .background(KadenceTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectionActionBar: some View {
        if isSelecting {
            HStack(spacing: 14) {
                Text(selectedIDs.isEmpty ? "Select habits to archive or delete" : "\(selectedIDs.count) selected")
                    .font(KadenceTheme.bodyFont(13))
                    .foregroundStyle(KadenceTheme.textMuted)
                Spacer()
                if !selectedIDs.isEmpty {
                    if scope == .active {
                        Button("Archive") { isConfirmingBulkArchive = true }
                            .font(KadenceTheme.bodyFontSemibold(13))
                            .foregroundStyle(KadenceTheme.ariesEmber)
                    }
                    if permanentDeletionEnabled {
                        Button("Delete") { isConfirmingBulkDelete = true }
                            .font(KadenceTheme.bodyFontSemibold(13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(KadenceTheme.ariesEmber)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                if isBulkActing {
                    ProgressView().tint(KadenceTheme.textMuted)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            if scope == .active {
                Text("No habits yet.")
                    .font(KadenceTheme.bodyFont(15))
                    .foregroundStyle(KadenceTheme.textMuted)

                Button {
                    formMode = .create
                } label: {
                    Text("Add your first habit")
                        .font(KadenceTheme.bodyFontSemibold(15))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .background(KadenceTheme.piscesTeal)
                .foregroundStyle(KadenceTheme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("No archived habits.")
                    .font(KadenceTheme.bodyFont(15))
                    .foregroundStyle(KadenceTheme.textMuted)
            }
        }
    }

    private func load() async {
        do {
            async let activeTask = HabitService.fetchActive()
            async let archivedTask = HabitService.fetchArchived()
            activeHabits = try await activeTask
            archivedHabits = try await archivedTask
            status = ""
        } catch is CancellationError {
            // This view's .task gets restarted when a nested sheet (the
            // habit edit form) dismisses, cancelling whichever load() was
            // already in flight — a newer one already ran and is reflected
            // in the list, so this isn't a real failure to report.
        } catch {
            status = "Couldn't load: \(error.localizedDescription)"
        }
    }

    private func unarchive(_ habit: Habit) {
        Task {
            do {
                try await HabitService.unarchive(habit.id)
                await load()
            } catch {
                status = "Couldn't restore: \(error.localizedDescription)"
            }
        }
    }

    private func bulkArchive() async {
        isBulkActing = true
        defer { isBulkActing = false }
        for id in selectedIDs {
            try? await HabitService.archive(id)
        }
        isSelecting = false
        selectedIDs = []
        await load()
    }

    private func bulkDelete() async {
        isBulkActing = true
        defer { isBulkActing = false }
        for id in selectedIDs {
            try? await HabitService.delete(id)
        }
        isSelecting = false
        selectedIDs = []
        await load()
    }
}

#Preview {
    ManageHabitsView()
}
