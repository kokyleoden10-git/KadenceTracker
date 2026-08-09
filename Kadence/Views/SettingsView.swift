import SwiftUI

/// Spec §7a. Profile fields are plain text (including birthdate/birth time
/// as "YYYY-MM-DD"/"HH:MM" strings) rather than pickers — this is a
/// single-user utility app, and plain text keeps the form simple and
/// consistent rather than adding picker/toggle state for rarely-edited
/// fields.
struct SettingsView: View {
    @State private var profile: Profile?
    @State private var email: String = ""

    @State private var nickname = ""
    @State private var birthdate = ""
    @State private var birthTime = ""
    @State private var birthLocation = ""
    @State private var currentLocation = ""

    @State private var isSaving = false
    @State private var statusMessage: String?

    @State private var includeSensitiveInExport = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var isImportPickerPresented = false

    @State private var isConfirmingReset = false
    @State private var isResetting = false

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
            labeledField("Birthdate (YYYY-MM-DD)", text: $birthdate)
            labeledField("Birth time (HH:MM)", text: $birthTime)
            labeledField("Birth location", text: $birthLocation)
            labeledField("Current location", text: $currentLocation)

            Button(action: save) {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Save")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(KadenceTheme.piscesTeal)
            .foregroundStyle(KadenceTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(isSaving)

            if let statusMessage {
                Text(statusMessage)
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
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
                .background(KadenceTheme.surface)
                .foregroundStyle(disabled ? KadenceTheme.textMuted : KadenceTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func load() async {
        email = AuthService.shared.session?.user.email ?? ""
        guard let loaded = try? await ProfileService.fetchCurrent() else { return }
        profile = loaded
        nickname = loaded.nickname ?? ""
        birthLocation = loaded.birthLocation ?? ""
        currentLocation = loaded.currentLocation ?? ""
        birthTime = loaded.birthTime ?? ""
        if let date = loaded.birthdate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            birthdate = formatter.string(from: date)
        }
    }

    private func save() {
        guard let userId = AuthService.shared.session?.user.id else { return }
        isSaving = true
        statusMessage = nil
        Task {
            defer { isSaving = false }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let values = ProfileService.ProfileUpdate(
                nickname: nickname.isEmpty ? nil : nickname,
                currentLocation: currentLocation.isEmpty ? nil : currentLocation,
                birthLocation: birthLocation.isEmpty ? nil : birthLocation,
                birthdate: birthdate.isEmpty ? nil : formatter.date(from: birthdate),
                birthTime: birthTime.isEmpty ? nil : birthTime
            )
            do {
                try await ProfileService.update(userId, with: values)
                statusMessage = "Saved."
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
