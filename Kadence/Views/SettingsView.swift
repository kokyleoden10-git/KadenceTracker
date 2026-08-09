import SwiftUI

/// Spec §7a. Birthdate always has a concrete value (DatePicker can't
/// represent "unset" without extra state) — birth time gets that extra
/// state since it's explicitly removable per product feedback, birthdate
/// isn't. Locations use MapKit autocomplete but stay freeform text
/// underneath — picking a suggestion just fills the field.
struct SettingsView: View {
    @State private var profile: Profile?
    @State private var email: String = ""

    @State private var nickname = ""
    @State private var birthdateDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    @State private var hasBirthTime = false
    @State private var birthTimeDate = Calendar.current.date(from: DateComponents(hour: 12, minute: 0)) ?? Date()
    @State private var birthLocation = ""
    @State private var currentLocation = ""

    @State private var isSaving = false
    @State private var showSavedConfirmation = false
    @State private var statusMessage: String?

    @State private var includeSensitiveInExport = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var isImportPickerPresented = false

    @State private var isConfirmingReset = false
    @State private var isResetting = false

    @AppStorage("permanentDeletionEnabled") private var permanentDeletionEnabled = false
    @State private var isConfirmingEnableDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                profileSection
                dataSection
                dangerZoneSection
            }
            .padding()
        }
        .background(KadenceTheme.bg.ignoresSafeArea())
        .task { await load() }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Profile")

            labeledField("Email", text: .constant(email), disabled: true)
            labeledField("Nickname", text: $nickname)
            labeledDateField("Birthdate", selection: $birthdateDate, components: .date)
            birthTimeField
            LocationSearchField(
                label: "Birth location",
                text: $birthLocation,
                infoText: "Used along with your birthdate and birth time to calculate your ascendant (rising) sign."
            )
            LocationSearchField(
                label: "Current location",
                text: $currentLocation,
                infoText: "Used to show your local weather on the Today screen, via Open-Meteo."
            )

            Button(action: save) {
                Group {
                    if isSaving {
                        ProgressView()
                    } else if showSavedConfirmation {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("Save")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 40)
            }
            .background(showSavedConfirmation ? KadenceTheme.piscesSeafoam : KadenceTheme.piscesTeal)
            .foregroundStyle(KadenceTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(isSaving)

            if let statusMessage {
                Text(statusMessage)
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.ariesEmber)
            }
        }
    }

    private var birthTimeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Birth time")
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
                InfoButton(text: "Used along with your birthdate and birth location to calculate your ascendant (rising) sign.")
            }

            if hasBirthTime {
                HStack {
                    DatePicker("Birth time", selection: $birthTimeDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(KadenceTheme.piscesTeal)
                        .environment(\.colorScheme, .dark)
                    Spacer()
                    Button {
                        hasBirthTime = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(KadenceTheme.textMuted)
                    }
                }
                .padding(10)
                .background(KadenceTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Button {
                    hasBirthTime = true
                } label: {
                    Text("Add birth time")
                        .font(KadenceTheme.bodyFont(14))
                        .foregroundStyle(KadenceTheme.piscesTeal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(KadenceTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Data")

            Toggle(isOn: $includeSensitiveInExport) {
                Text("Include sensitive entries in export")
                    .font(KadenceTheme.bodyFont(14))
                    .foregroundStyle(KadenceTheme.textPrimary)
            }
            .tint(KadenceTheme.piscesTeal)

            Button(action: startExport) {
                if isExporting {
                    ProgressView()
                } else {
                    Text("Export Log")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(KadenceTheme.surface)
            .foregroundStyle(KadenceTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(isExporting)

            if let exportURL {
                ShareLink("Save Export…", item: exportURL)
                    .font(KadenceTheme.bodyFont(14))
                    .foregroundStyle(KadenceTheme.piscesTeal)
            }

            Button(action: { isImportPickerPresented = true }) {
                if isImporting {
                    ProgressView()
                } else {
                    Text("Import Backup")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(KadenceTheme.surface)
            .foregroundStyle(KadenceTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(isImporting)
            .fileImporter(isPresented: $isImportPickerPresented, allowedContentTypes: [.json]) { result in
                handleImportPick(result)
            }
        }
    }

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Danger Zone")

            Toggle(isOn: Binding(
                get: { permanentDeletionEnabled },
                set: { newValue in
                    if newValue {
                        isConfirmingEnableDelete = true
                    } else {
                        permanentDeletionEnabled = false
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allow permanently deleting habits")
                        .font(KadenceTheme.bodyFont(14))
                        .foregroundStyle(KadenceTheme.textPrimary)
                    Text("Off by default. When off, only Archive is available when editing a habit.")
                        .font(KadenceTheme.bodyFont(11))
                        .foregroundStyle(KadenceTheme.textMuted)
                }
            }
            .tint(KadenceTheme.ariesEmber)
            .alert("Allow Permanent Deletion?", isPresented: $isConfirmingEnableDelete) {
                Button("Enable", role: .destructive) { permanentDeletionEnabled = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This lets you permanently delete a habit from its edit screen. Deleting a habit also destroys every entry you've ever logged for it — there's no undo and no backup copy.")
            }

            Button("Sign Out") {
                Task { try? await AuthService.shared.signOut() }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(KadenceTheme.surface)
            .foregroundStyle(KadenceTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Clear All Data & Reset") {
                isConfirmingReset = true
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(KadenceTheme.ariesEmber)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(isResetting)
            .confirmationDialog(
                "This permanently deletes every habit, log entry, reading, signal, and reflection. This can't be undone.",
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    Task { await clearAllData() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(KadenceTheme.displayFont(20))
            .foregroundStyle(KadenceTheme.textPrimary)
    }

    private func labeledDateField(_ label: String, selection: Binding<Date>, components: DatePickerComponents) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
            DatePicker(label, selection: selection, displayedComponents: components)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(KadenceTheme.piscesTeal)
                .environment(\.colorScheme, .dark)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KadenceTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    /// `disabled` fields (just Email today) are styled flatter and dimmer
    /// so it's visually obvious they're not editable, not just functionally
    /// blocked.
    private func labeledField(_ label: String, text: Binding<String>, disabled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
            TextField(label, text: text)
                .disabled(disabled)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(10)
                .background(disabled ? KadenceTheme.bg : KadenceTheme.surface)
                .foregroundStyle(KadenceTheme.textMuted)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(KadenceTheme.textMuted.opacity(disabled ? 0.15 : 0), lineWidth: 1)
                )
                .opacity(disabled ? 0.7 : 1)
        }
    }

    private func load() async {
        email = AuthService.shared.session?.user.email ?? ""
        guard let loaded = try? await ProfileService.fetchCurrent() else { return }
        profile = loaded
        nickname = loaded.nickname ?? ""
        birthLocation = loaded.birthLocation ?? ""
        currentLocation = loaded.currentLocation ?? ""

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let birthdate = loaded.birthdate, let parsed = dateFormatter.date(from: birthdate) {
            birthdateDate = parsed
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        if let birthTime = loaded.birthTime, let parsed = timeFormatter.date(from: birthTime) {
            birthTimeDate = parsed
            hasBirthTime = true
        }
    }

    private func save() {
        guard let userId = AuthService.shared.session?.user.id else { return }
        isSaving = true
        statusMessage = nil
        Task {
            defer { isSaving = false }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"

            let values = ProfileService.ProfileUpdate(
                nickname: nickname.isEmpty ? nil : nickname,
                currentLocation: currentLocation.isEmpty ? nil : currentLocation,
                birthLocation: birthLocation.isEmpty ? nil : birthLocation,
                birthdate: dateFormatter.string(from: birthdateDate),
                birthTime: hasBirthTime ? timeFormatter.string(from: birthTimeDate) : nil
            )
            do {
                try await ProfileService.update(userId, with: values)
                showSavedConfirmation = true
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    showSavedConfirmation = false
                }
            } catch {
                statusMessage = "Couldn't save: \(error.localizedDescription)"
            }
        }
    }

    private func startExport() {
        isExporting = true
        statusMessage = nil
        Task {
            defer { isExporting = false }
            do {
                exportURL = try await DataExportService.exportToFile(includeSensitive: includeSensitiveInExport)
            } catch {
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func handleImportPick(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            statusMessage = "Import failed: \(error.localizedDescription)"
        case .success(let url):
            isImporting = true
            statusMessage = nil
            Task {
                defer { isImporting = false }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    try await DataExportService.importBundle(from: url)
                    statusMessage = "Import complete."
                } catch {
                    statusMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func clearAllData() async {
        isResetting = true
        defer { isResetting = false }
        do {
            try await DataExportService.clearAllData()
            statusMessage = "All data cleared."
        } catch {
            statusMessage = "Couldn't clear data: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsView()
}
