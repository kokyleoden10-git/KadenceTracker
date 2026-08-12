import SwiftUI

/// Entry of a chart the user already has (from a prior reading, astro.com,
/// etc.) rather than computing one — see TarotModels.swift's NatalChart
/// doc comment for why. Sign-only, no degrees: that's all the resonance
/// engine's scoring actually needs.
///
/// Birth date/time/place used to be typed here too, duplicating the same
/// fields already collected in Settings → Profile. They're now read from
/// the profile automatically and shown for reference only — nothing left
/// to fill in here except the placements themselves, which still need a
/// human source since there's no ephemeris computing them.
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

    /// Frozen snapshot of the profile's birth data at the moment this chart
    /// was saved — sourced automatically, never typed. Spec's own logic for
    /// why this needs to be frozen rather than a live read: "if a user later
    /// corrects their birth time, past entries must still read as they did
    /// on the day."
    @State private var birthDateDescription = ""
    @State private var birthTimeDescription = ""
    @State private var birthLocationDescription = ""
    @State private var isSaving = false
    @State private var status: String?

    private var hasBirthDataOnFile: Bool {
        !birthDateDescription.isEmpty || !birthLocationDescription.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Enter the placements from a chart you already trust (astro.com, a prior reading). This app doesn't calculate charts itself.")
                        .font(KadenceTheme.bodyFont(13))
                        .foregroundStyle(KadenceTheme.textMuted)

                    birthDataReference

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
        .task { await populate() }
    }

    private var birthDataReference: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FROM YOUR PROFILE")
                .font(KadenceTheme.bodyFontSemibold(10))
                .tracking(1.2)
                .foregroundStyle(KadenceTheme.textMuted)
            if hasBirthDataOnFile {
                Text([birthDateDescription, birthTimeDescription, birthLocationDescription]
                    .filter { !$0.isEmpty }
                    .joined(separator: " \u{00B7} "))
                    .font(KadenceTheme.bodyFont(14))
                    .foregroundStyle(KadenceTheme.textPrimary)
                Text("Wrong? Edit it in Settings \u{2192} Profile.")
                    .font(KadenceTheme.bodyFont(11))
                    .foregroundStyle(KadenceTheme.textMuted)
            } else {
                Text("No birthdate or birth location on file yet. Add them in Settings \u{2192} Profile so this chart keeps a record of what it's based on. The placements below still come from a chart you trust either way — this app doesn't calculate them.")
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KadenceTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

    private func populate() async {
        if let chart = existingChart {
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
        }

        // Always sourced fresh from the profile rather than kept from
        // whenever the chart was last saved — this is just a reference
        // label, not the frozen resonance notes on past draws, so there's
        // no reason to let it drift from what the profile actually says.
        guard let profile = try? await ProfileService.fetchCurrent() else { return }

        if let birthdate = profile.birthdate {
            let input = DateFormatter()
            input.dateFormat = "yyyy-MM-dd"
            let output = DateFormatter()
            output.dateFormat = "MMM d, yyyy"
            birthDateDescription = input.date(from: birthdate).map { output.string(from: $0) } ?? birthdate
        }
        if let birthTime = profile.birthTime {
            let input = DateFormatter()
            input.dateFormat = "HH:mm:ss"
            let output = DateFormatter()
            output.dateFormat = "h:mm a"
            birthTimeDescription = input.date(from: birthTime).map { output.string(from: $0) } ?? birthTime
        }
        birthLocationDescription = profile.birthLocation ?? ""
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
