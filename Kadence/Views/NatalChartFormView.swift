import SwiftData
import SwiftUI

/// One-time entry of a chart the user already has (from a prior reading,
/// astro.com, etc.) rather than computing one — see TarotModels.swift's
/// NatalChart doc comment for why. Sign-only, no degrees: that's all the
/// resonance engine's scoring actually needs.
struct NatalChartFormView: View {
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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

    private func save() {
        let chart = NatalChart(
            sun: sun, moon: moon, mercury: mercury, venus: venus, mars: mars,
            jupiter: jupiter, saturn: saturn, uranus: uranus, neptune: neptune,
            pluto: pluto, ascendant: ascendant, midheaven: midheaven
        )
        chart.birthDateDescription = birthDateDescription.isEmpty ? nil : birthDateDescription
        chart.birthTimeDescription = birthTimeDescription.isEmpty ? nil : birthTimeDescription
        chart.birthLocationDescription = birthLocationDescription.isEmpty ? nil : birthLocationDescription
        modelContext.insert(chart)
        onSaved()
        dismiss()
    }
}

#Preview {
    NatalChartFormView(onSaved: {})
}
