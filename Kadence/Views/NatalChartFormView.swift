import SwiftData
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
    var existingChart: NatalChart?
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \NatalChart.createdAt) private var allCharts: [NatalChart]

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

                    Button("Save Chart") { save() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(KadenceTheme.piscesTeal)
                        .foregroundStyle(KadenceTheme.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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

    private func save() {
        let chart = existingChart ?? NatalChart(
            sun: sun, moon: moon, mercury: mercury, venus: venus, mars: mars,
            jupiter: jupiter, saturn: saturn, uranus: uranus, neptune: neptune,
            pluto: pluto, ascendant: ascendant, midheaven: midheaven
        )
        chart.sun = sun
        chart.moon = moon
        chart.mercury = mercury
        chart.venus = venus
        chart.mars = mars
        chart.jupiter = jupiter
        chart.saturn = saturn
        chart.uranus = uranus
        chart.neptune = neptune
        chart.pluto = pluto
        chart.ascendant = ascendant
        chart.midheaven = midheaven
        chart.birthDateDescription = birthDateDescription.isEmpty ? nil : birthDateDescription
        chart.birthTimeDescription = birthTimeDescription.isEmpty ? nil : birthTimeDescription
        chart.birthLocationDescription = birthLocationDescription.isEmpty ? nil : birthLocationDescription

        if existingChart == nil {
            modelContext.insert(chart)
        }

        // There should only ever be one chart. Earlier builds could create
        // duplicates (the reopen-resets-to-Aries bug), so clean up any
        // strays here rather than leaving it ambiguous which one resonance
        // reads from.
        for stray in allCharts where stray !== chart {
            modelContext.delete(stray)
        }

        onSaved()
        dismiss()
    }
}

#Preview {
    NatalChartFormView(onSaved: {})
}
