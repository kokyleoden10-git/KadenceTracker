import SwiftUI

/// Entry of a chart the user already has (from a prior reading, astro.com,
/// etc.) rather than computing one — see TarotModels.swift's NatalChart
/// doc comment for why. Sign-only, no degrees: that's all the resonance
/// engine's scoring actually needs.
///
/// Acts as a singleton editor: if `existingChart` is passed in, every
/// field is pre-populated from it and Save updates that same record in
/// place. Without this, reopening the form always showed Aries defaults
/// and re-saving created a second, blank NatalChart — with two records
/// and no explicit sort on the `@Query` in DrawView, which one counted as
/// "the" chart was unpredictable, which is exactly the bug this fixes.
struct NatalChartFormView: View {
    var existingChart: RemoteNatalChart?
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sun: ZodiacSign = .aries
    @State private var moon: ZodiacSign = .aries
    @State private var mercury: ZodiacSign = .aries
    @State private var venus: ZodiacSign = .aries
    @State private var mars: ZodiacSign = .aries
    @State private var jupiter: ZodiacSign = .aries
    @State private var saturn: ZodiacSign = .aries
    @State private var uranus: ZodiacSign = .aries
    @State private var neptune: ZodiacSign = .aries
    @State private var pluto: ZodiacSign = .aries
    @State private var ascendant: ZodiacSign = .aries
    @State private var midheaven: ZodiacSign = .aries

    @State private var birthDateDescription = ""
    @State private var birthTimeDescription = ""
    @State private var birthLocationDescription = ""
    @State private var isSaving = false
    @State private var status: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Enter the placements from a chart you already trust (astro.com, a prior reading). This app doesn't calculate charts itself.")
                        .font(KadenceTheme.bodyFont(13))
                        .foregroundStyle(KadenceTheme.textMuted)

                    signRow("Sun", $sun)
                    signRow("Moon", $moon)
                    signRow("Mercury", $mercury)
                    signRow("Venus", $venus)
                    signRow("Mars", $mars)
                    signRow("Jupiter", $jupiter)
                    signRow("Saturn", $saturn)
                    signRow("Uranus", $uranus)
                    signRow("Neptune", $neptune)
                    signRow("Pluto", $pluto)
                    signRow("Ascendant", $ascendant)
                    signRow("Midheaven", $midheaven)

                    Divider().overlay(KadenceTheme.textMuted.opacity(0.2))

                    labeledField("Birth date (reference only)", text: $birthDateDescription)
                    labeledField("Birth time (reference only)", text: $birthTimeDescription)
                    labeledField("Birth place (reference only)", text: $birthLocationDescription)

                    Button { Task { await save() } } label: {
                        Group {
                            if isSaving { ProgressView() } else { Text("Save Chart") }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .background(KadenceTheme.piscesTeal)
                    .foregroundStyle(KadenceTheme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(isSaving)

                    if let status {
                        Text(status)
                            .font(KadenceTheme.bodyFont(12))
                            .foregroundStyle(KadenceTheme.ariesEmber)
                    }
                }
                .padding()
            }
            .background(KadenceTheme.bg.ignoresSafeArea())
            .navigationTitle("Your Chart")
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

    private func signRow(_ label: String, _ selection: Binding<ZodiacSign>) -> some View {
        HStack {
            Text(label)
                .font(KadenceTheme.bodyFont(14))
                .foregroundStyle(KadenceTheme.textPrimary)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(ZodiacSign.allCases) { sign in
                    Text(sign.displayName).tag(sign)
                }
            }
            .tint(KadenceTheme.piscesTeal)
        }
        .padding(10)
        .background(KadenceTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
            TextField(label, text: text)
                .padding(10)
                .background(KadenceTheme.surface)
                .foregroundStyle(KadenceTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func populateIfEditing() {
        guard let chart = existingChart else { return }
        sun = chart.sun
        moon = chart.moon
        mercury = chart.mercury
        venus = chart.venus
        mars = chart.mars
        jupiter = chart.jupiter
        saturn = chart.saturn
        uranus = chart.uranus
        neptune = chart.neptune
        pluto = chart.pluto
        ascendant = chart.ascendant
        midheaven = chart.midheaven
        birthDateDescription = chart.birthDateDescription ?? ""
        birthTimeDescription = chart.birthTimeDescription ?? ""
        birthLocationDescription = chart.birthLocationDescription ?? ""
    }

    /// Upserts on user_id, which is the table's primary key — editing
    /// replaces the one chart rather than creating a second, so the
    /// duplicate-chart cleanup the SwiftData version needed is gone.
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await NatalChartService.save(
                NatalChartService.ChartInput(
                    userId: try await SupabaseService.shared.requireUserId(),
                    sun: sun, moon: moon, mercury: mercury, venus: venus, mars: mars,
                    jupiter: jupiter, saturn: saturn, uranus: uranus, neptune: neptune,
                    pluto: pluto, ascendant: ascendant, midheaven: midheaven,
                    birthDateDescription: birthDateDescription.isEmpty ? nil : birthDateDescription,
                    birthTimeDescription: birthTimeDescription.isEmpty ? nil : birthTimeDescription,
                    birthLocationDescription: birthLocationDescription.isEmpty ? nil : birthLocationDescription,
                    userNote: existingChart?.userNote
                )
            )
            onSaved()
            dismiss()
        } catch {
            status = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NatalChartFormView(onSaved: {})
}
