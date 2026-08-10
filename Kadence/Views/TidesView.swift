import SwiftUI

/// Replaces streaks (Cosmic Container spec §2). A missed day is a low
/// tide — present in the shape, never marked as a failure. There is
/// deliberately no "best run", no chain, and no red anywhere in here.
///
/// Ships with both treatments behind a toggle so they can be compared on
/// a real device with real data before one is committed to:
///
/// - **Table** honours the v3 banned list — no gradients, no glow, no
///   illustration. Reads like a tide table.
/// - **Water** follows the Cosmic Container spec — a filled wave and a
///   rising level, i.e. "a gathering of water".
struct TidesView: View {
    enum Treatment: String, CaseIterable {
        case table = "Table"
        case water = "Water"
    }

    private static let windowLength = 30

    @AppStorage("tidesTreatment") private var treatmentRaw = Treatment.table.rawValue
    private var treatment: Treatment { Treatment(rawValue: treatmentRaw) ?? .table }

    @State private var days: [DayVolume] = []
    @State private var status = "Loading\u{2026}"

    /// TEMPORARY scaffolding for choosing between the two treatments. With
    /// only a day or two of real entries both shapes render as a single
    /// blip, which says nothing about the design. Purely in-memory —
    /// nothing is written to Supabase — and this whole toggle should be
    /// deleted once a treatment is picked.
    @State private var showSample = false

    struct DayVolume: Identifiable {
        let date: Date
        let completed: Int
        var id: Date { date }
    }

    private var peak: Int { max(days.map(\.completed).max() ?? 0, 1) }
    private var total: Int { days.reduce(0) { $0 + $1.completed } }
    private var mean: Double {
        days.isEmpty ? 0 : Double(total) / Double(days.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    Picker("Treatment", selection: $treatmentRaw) {
                        ForEach(Treatment.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: $showSample) {
                        Text("Show sample shape")
                            .font(KadenceTheme.bodyFont(13))
                            .foregroundStyle(KadenceTheme.textMuted)
                    }
                    .tint(KadenceTheme.piscesTeal)
                    .onChange(of: showSample) { _, _ in Task { await load() } }

                    if !status.isEmpty {
                        Text(status)
                            .font(KadenceTheme.bodyFont(14))
                            .foregroundStyle(KadenceTheme.textMuted)
                    } else {
                        if showSample {
                            Text("SAMPLE \u{2014} NOT YOUR DATA")
                                .font(KadenceTheme.bodyFontSemibold(10))
                                .tracking(1.2)
                                .foregroundStyle(KadenceTheme.ariesEmber)
                        }
                        switch treatment {
                        case .table: tableTreatment
                        case .water: waterTreatment
                        }
                        readout
                    }
                }
                .padding()
            }
            .background(KadenceTheme.bg.ignoresSafeArea())
            .refreshable { await load() }
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TIDES")
                .font(KadenceTheme.bodyFontSemibold(12))
                .tracking(1.4)
                .foregroundStyle(KadenceTheme.textMuted)
            Text("Last 30 days")
                .font(KadenceTheme.displayFont(28))
                .foregroundStyle(KadenceTheme.textPrimary)
        }
    }

    // MARK: - Table treatment

    private var tableTreatment: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                let columnWidth = proxy.size.width / CGFloat(Self.windowLength)
                ZStack(alignment: .bottomLeading) {
                    // Mean line, so a day reads against your own baseline
                    // rather than against a target.
                    let meanHeight = proxy.size.height * (mean / Double(peak))
                    Rectangle()
                        .fill(KadenceTheme.textMuted.opacity(0.25))
                        .frame(height: 1)
                        .offset(y: -meanHeight)

                    HStack(alignment: .bottom, spacing: 1) {
                        ForEach(days) { day in
                            Rectangle()
                                .fill(barColor(for: day))
                                .frame(
                                    width: max(columnWidth - 1, 1),
                                    height: max(proxy.size.height * (Double(day.completed) / Double(peak)), 1)
                                )
                        }
                    }
                }
            }
            .frame(height: 140)

            axisLabels
        }
    }

    /// Empty days still draw a hairline so the rhythm stays legible —
    /// a gap you can see, not a gap that indicts you.
    private func barColor(for day: DayVolume) -> Color {
        day.completed == 0
            ? KadenceTheme.textMuted.opacity(0.22)
            : KadenceTheme.piscesTeal
    }

    // MARK: - Water treatment

    private var waterTreatment: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                let points = wavePoints(in: proxy.size)
                ZStack {
                    // Filled body of water under the curve.
                    smoothPath(through: points, closingIn: proxy.size)
                        .fill(
                            LinearGradient(
                                colors: [
                                    KadenceTheme.piscesSeafoam.opacity(0.45),
                                    KadenceTheme.piscesTeal.opacity(0.05),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Surface line.
                    smoothPath(through: points, closingIn: nil)
                        .stroke(KadenceTheme.piscesSeafoam, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                    // Today, marked without a number attached to it.
                    if let last = points.last {
                        Circle()
                            .fill(KadenceTheme.piscesSeafoam)
                            .frame(width: 7, height: 7)
                            .position(last)
                    }
                }
            }
            .frame(height: 160)

            axisLabels
        }
    }

    private func wavePoints(in size: CGSize) -> [CGPoint] {
        guard days.count > 1 else { return [] }
        let stepX = size.width / CGFloat(days.count - 1)
        return days.enumerated().map { index, day in
            let ratio = Double(day.completed) / Double(peak)
            // Inset from the very top/bottom so the curve reads as a water
            // surface with depth rather than a chart clipping its bounds.
            let y = size.height - (size.height * 0.85 * ratio) - size.height * 0.05
            return CGPoint(x: CGFloat(index) * stepX, y: y)
        }
    }

    /// Quadratic smoothing through midpoints — enough to feel fluid, and
    /// it can't overshoot into false peaks the way a cubic spline can.
    private func smoothPath(through points: [CGPoint], closingIn size: CGSize?) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: midpoint, control: previous)
        }
        if let last = points.last {
            path.addLine(to: last)
        }
        if let size, let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.addLine(to: CGPoint(x: first.x, y: size.height))
            path.closeSubpath()
        }
        return path
    }

    // MARK: - Shared

    private var axisLabels: some View {
        HStack {
            Text(days.first.map(shortDate) ?? "")
            Spacer()
            Text("Today")
        }
        .font(KadenceTheme.bodyFont(11))
        .foregroundStyle(KadenceTheme.textMuted)
    }

    /// Cumulative volume rather than consecutive days — the whole point of
    /// the replacement. "Rested" is the neutral word for a zero day.
    private var readout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(total) logged across 30 days")
                .font(KadenceTheme.bodyFont(15))
                .foregroundStyle(KadenceTheme.textPrimary)
            Text("Fullest day \(peak) \u{00B7} typical day \(String(format: "%.1f", mean)) \u{00B7} \(days.filter { $0.completed == 0 }.count) rested")
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
        }
    }

    private func shortDate(_ day: DayVolume) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: day.date)
    }

    private func load() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(Self.windowLength - 1), to: today) else { return }

        if showSample {
            // Deterministic, with genuine rest days and an uneven rhythm —
            // a flattering smooth curve would misrepresent both designs.
            let pattern = [3, 4, 2, 0, 1, 3, 5, 4, 0, 0, 2, 3, 4, 6, 5, 3,
                           1, 0, 2, 4, 5, 5, 3, 0, 1, 2, 4, 3, 5, 4]
            days = (0..<Self.windowLength).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                return DayVolume(date: date, completed: pattern[offset % pattern.count])
            }
            status = ""
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        do {
            let entries = try await LogEntryService.fetchRange(from: start, to: today)
            // Keyed on the raw "yyyy-MM-dd" string rather than a parsed
            // Date — log_entry.date is a bare Postgres date, so comparing
            // strings sidesteps any timezone shifting a round-trip through
            // Date could introduce.
            var counts: [String: Int] = [:]
            for entry in entries where entry.doneValue > 0 {
                counts[entry.date, default: 0] += 1
            }
            days = (0..<Self.windowLength).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                return DayVolume(date: date, completed: counts[formatter.string(from: date)] ?? 0)
            }
            status = ""
        } catch is CancellationError {
            // Superseded reload; a newer one already reflects the data.
        } catch {
            status = "Couldn't load tides: \(error.localizedDescription)"
        }
    }
}

#Preview {
    TidesView()
}
