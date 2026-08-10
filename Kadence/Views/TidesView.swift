import SwiftUI

/// Replaces streaks (Cosmic Container spec §2). A missed day is a low
/// tide — present in the shape, never marked as a failure. No chain, no
/// best-run, no red.
///
/// The X axis is the lunar cycle rather than "day 1 to 30" (Analytics spec
/// §2), so the shape reads against the moon instead of against an
/// arbitrary window start. Background blocks tint by the element of the
/// moon's sign, giving the "blue behind water-sign days" context.
///
/// On the axis wrap: 30 calendar days is almost exactly one synodic month
/// (29.53), so the window tiles the axis roughly once. Where two calendar
/// days land on the same lunar day, their volumes are averaged — which is
/// also precisely the behaviour wanted later, when several cycles of
/// history fold onto this same axis to expose a real lunar pattern.
struct TidesView: View {
    enum Treatment: String, CaseIterable {
        case table = "Table"
        case water = "Water"
    }

    private static let windowLength = 30
    private static let lunarBins = 30

    /// Cycles of history before a lunar correlation could mean anything.
    /// Lunar rhythm has to be separated from the weekly rhythm habits
    /// already have, and that takes several full cycles — six is the floor,
    /// and v3's spec says a year for anything involving tarot suits.
    private static let cyclesNeededForCorrelation = 6

    @AppStorage("tidesTreatment") private var treatmentRaw = Treatment.table.rawValue
    private var treatment: Treatment { Treatment(rawValue: treatmentRaw) ?? .table }

    @State private var bins: [LunarBin] = []
    @State private var observedDays = 0
    /// Distinct logged days across *all* history, and the span they cover —
    /// the 30-day window alone can't project how long until there's enough
    /// data to say anything.
    @State private var lifetimeLoggedDays = 0
    @State private var lifetimeSpanDays = 0
    @State private var status = "Loading\u{2026}"

    /// TEMPORARY scaffolding for choosing a treatment — in-memory only,
    /// never written. Delete once a treatment is picked.
    @State private var showSample = false

    struct LunarBin: Identifiable {
        let lunarDay: Int
        let volume: Double
        let observations: Int
        let moonSign: ZodiacSign
        var id: Int { lunarDay }
        var hasData: Bool { observations > 0 }
    }

    private var peak: Double { max(bins.map(\.volume).max() ?? 0, 1) }
    private var total: Double { bins.reduce(0) { $0 + $1.volume } }
    private var restedDays: Int { bins.filter { $0.hasData && $0.volume == 0 }.count }

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
                    } else if observedDays == 0 {
                        emptyState
                    } else {
                        if showSample {
                            Text("SAMPLE \u{2014} NOT YOUR DATA")
                                .font(KadenceTheme.bodyFontSemibold(10))
                                .tracking(1.2)
                                .foregroundStyle(KadenceTheme.ariesEmber)
                        }
                        chart
                        phaseAxis
                        insights
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
            Text("Across the lunar cycle")
                .font(KadenceTheme.displayFont(28))
                .foregroundStyle(KadenceTheme.textPrimary)
            Text("Today \u{00B7} lunar day \(Int(MoonService.lunarAge(Date())) + 1) \u{00B7} \(MoonService.phase(Date()).rawValue) \u{00B7} moon in \(MoonService.sign(Date()).displayName)")
                .font(KadenceTheme.bodyFont(12))
                .foregroundStyle(KadenceTheme.textMuted)
        }
    }

    // MARK: - Empty state

    /// No chart, no tint blocks, no gradient — with nothing logged those
    /// render as a murky striped rectangle that looks broken. Just the
    /// shape of a tide and a line telling you what to do about it.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            TideGlyph()
                .stroke(KadenceTheme.piscesSeafoam.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(height: 90)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("No tide yet.")
                    .font(KadenceTheme.displayFont(20))
                    .foregroundStyle(KadenceTheme.textPrimary)
                Text("Log a few days and the shape starts to show. Nothing here counts against you.")
                    .font(KadenceTheme.bodyFont(13))
                    .foregroundStyle(KadenceTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Chart

    private var chart: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                moonSignBlocks(in: proxy.size)
                quarterMarkers(in: proxy.size)

                switch treatment {
                case .table: tableMarks(in: proxy.size)
                case .water: waterMarks(in: proxy.size)
                }
            }
        }
        .frame(height: 170)
    }

    /// Element of the moon's sign, tinted behind the chart — water reads
    /// blue-green, fire warm, and so on (Analytics spec §2).
    private func moonSignBlocks(in size: CGSize) -> some View {
        let binWidth = size.width / CGFloat(Self.lunarBins)
        return ForEach(bins) { bin in
            Rectangle()
                .fill(tint(for: bin.moonSign))
                .frame(width: binWidth, height: size.height)
                .offset(x: CGFloat(bin.lunarDay) * binWidth)
        }
    }

    private func tint(for sign: ZodiacSign) -> Color {
        switch element(of: sign) {
        case .water: return KadenceTheme.aquariusIce.opacity(0.10)
        case .fire: return KadenceTheme.ariesEmber.opacity(0.08)
        case .air: return KadenceTheme.sagittariusIndigo.opacity(0.09)
        case .earth: return KadenceTheme.capricornBronze.opacity(0.08)
        }
    }

    private func quarterMarkers(in size: CGSize) -> some View {
        // New / First Quarter / Full / Last Quarter, at cycle fractions.
        let fractions: [Double] = [0, 0.25, 0.5, 0.75]
        return ForEach(fractions, id: \.self) { fraction in
            Rectangle()
                .fill(KadenceTheme.textMuted.opacity(0.18))
                .frame(width: 1, height: size.height)
                .offset(x: size.width * fraction)
        }
    }

    private func tableMarks(in size: CGSize) -> some View {
        let binWidth = size.width / CGFloat(Self.lunarBins)
        return ForEach(bins) { bin in
            Rectangle()
                .fill(bin.volume > 0 ? KadenceTheme.piscesTeal : KadenceTheme.textMuted.opacity(0.22))
                .frame(
                    width: max(binWidth - 1.5, 1),
                    height: max(size.height * (bin.volume / peak), bin.hasData ? 1 : 0)
                )
                .offset(x: CGFloat(bin.lunarDay) * binWidth)
        }
    }

    private func waterMarks(in size: CGSize) -> some View {
        let points = wavePoints(in: size)
        return ZStack {
            smoothPath(through: points, closingIn: size)
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
            smoothPath(through: points, closingIn: nil)
                .stroke(KadenceTheme.piscesSeafoam, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// Only bins with observations become vertices — an unobserved lunar
    /// day shouldn't be drawn as a zero, which would fabricate a trough.
    private func wavePoints(in size: CGSize) -> [CGPoint] {
        let binWidth = size.width / CGFloat(Self.lunarBins)
        return bins.filter(\.hasData).map { bin in
            CGPoint(
                x: CGFloat(bin.lunarDay) * binWidth + binWidth / 2,
                y: size.height - (size.height * 0.85 * (bin.volume / peak)) - size.height * 0.05
            )
        }
    }

    private func smoothPath(through points: [CGPoint], closingIn size: CGSize?) -> Path {
        var path = Path()
        guard let first = points.first, points.count > 1 else { return path }
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

    private var phaseAxis: some View {
        HStack(spacing: 0) {
            Text("New")
            Spacer()
            Text("First Qtr")
            Spacer()
            Text("Full")
            Spacer()
            Text("Last Qtr")
            Spacer()
            Text("New")
        }
        .font(KadenceTheme.bodyFont(10))
        .foregroundStyle(KadenceTheme.textMuted)
    }

    // MARK: - Insights

    /// Plain counts are always shown — they're facts, not claims. Anything
    /// that invites reading a pattern is withheld entirely until there's
    /// enough history for it to mean something, rather than shown early
    /// with a caveat: a caveated number still gets believed.
    private var insights: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(Int(total.rounded())) logged \u{00B7} \(observedDays) days observed \u{00B7} \(restedDays) rested")
                .font(KadenceTheme.bodyFont(15))
                .foregroundStyle(KadenceTheme.textPrimary)

            patternsSection
        }
    }

    private var hasEnoughForPatterns: Bool {
        Double(lifetimeLoggedDays) >= Double(Self.cyclesNeededForCorrelation) * MoonService.synodicMonth
    }

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(KadenceTheme.textMuted.opacity(0.2))
            Text("PATTERNS")
                .font(KadenceTheme.bodyFontSemibold(10))
                .tracking(1.2)
                .foregroundStyle(KadenceTheme.textMuted)

            if hasEnoughForPatterns {
                ForEach(observations, id: \.self) { line in
                    Text(line)
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(waitingDescription)
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// States the requirement and projects a date from the actual logging
    /// rate, so the wait is a known quantity rather than an indefinite one.
    private var waitingDescription: String {
        let neededDays = Int((Double(Self.cyclesNeededForCorrelation) * MoonService.synodicMonth).rounded())
        let remaining = max(neededDays - lifetimeLoggedDays, 0)

        guard lifetimeLoggedDays > 0, lifetimeSpanDays > 0 else {
            return "Readings need about \(neededDays) logged days \u{2014} six lunar cycles, enough to tell a moon rhythm from an ordinary weekly one. Keep logging and this will estimate when."
        }

        let rate = min(max(Double(lifetimeLoggedDays) / Double(lifetimeSpanDays), 0.01), 1)
        let projectedDays = Double(remaining) / rate
        return "\(lifetimeLoggedDays) of about \(neededDays) logged days \u{2014} six lunar cycles, enough to tell a moon rhythm from an ordinary weekly one. At your pace so far, roughly \(humanDuration(projectedDays)) to go."
    }

    private func humanDuration(_ days: Double) -> String {
        switch days {
        case ..<14: return "\(max(Int(days.rounded()), 1)) days"
        case ..<60: return "\(Int((days / 7).rounded())) weeks"
        case ..<550: return "\(max(Int((days / 30.44).rounded()), 2)) months"
        default: return "over a year"
        }
    }

    private var observations: [String] {
        guard let fullest = bins.filter(\.hasData).max(by: { $0.volume < $1.volume }), fullest.volume > 0 else {
            return ["Nothing logged in this window yet."]
        }

        var lines: [String] = []
        let phaseName = MoonService.phase(dateForLunarDay(fullest.lunarDay)).rawValue
        lines.append("Fullest so far: lunar day \(fullest.lunarDay + 1) (\(phaseName.lowercased())).")

        // Waxing vs waning halves, with counts attached so the reader can
        // see how thin the evidence is.
        let waxing = bins.filter { $0.hasData && $0.lunarDay < Self.lunarBins / 2 }
        let waning = bins.filter { $0.hasData && $0.lunarDay >= Self.lunarBins / 2 }
        if !waxing.isEmpty, !waning.isEmpty {
            let waxingMean = waxing.reduce(0) { $0 + $1.volume } / Double(waxing.count)
            let waningMean = waning.reduce(0) { $0 + $1.volume } / Double(waning.count)
            lines.append(String(
                format: "Waxing days averaged %.1f across %d days; waning %.1f across %d.",
                waxingMean, waxing.count, waningMean, waning.count
            ))
        }

        let waterDays = bins.filter { $0.hasData && element(of: $0.moonSign) == .water }
        if !waterDays.isEmpty {
            let mean = waterDays.reduce(0) { $0 + $1.volume } / Double(waterDays.count)
            lines.append(String(
                format: "Water-sign moon days averaged %.1f across %d days.",
                mean, waterDays.count
            ))
        }
        return lines
    }

    private func dateForLunarDay(_ lunarDay: Int) -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        let todayLunarDay = Int(MoonService.lunarAge(today))
        let delta = lunarDay - todayLunarDay
        return Calendar.current.date(byAdding: .day, value: delta, to: today) ?? today
    }

    // MARK: - Load

    private func load() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(Self.windowLength - 1), to: today) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Completions drive the volume, but *any* row makes a day observed —
        // a day where everything was marked not-done is a real, deliberate
        // low tide, and must not vanish from the denominator. Without that
        // distinction "rested" would always read 0.
        var completions: [String: Int] = [:]
        var observedDates: Set<String> = []

        if showSample {
            let pattern = [3, 4, 2, 0, 1, 3, 5, 4, 0, 0, 2, 3, 4, 6, 5, 3,
                           1, 0, 2, 4, 5, 5, 3, 0, 1, 2, 4, 3, 5, 4]
            for offset in 0..<Self.windowLength {
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                let key = formatter.string(from: date)
                completions[key] = pattern[offset % pattern.count]
                observedDates.insert(key)
            }
            lifetimeLoggedDays = Self.windowLength
            lifetimeSpanDays = Self.windowLength
        } else {
            do {
                let entries = try await LogEntryService.fetchRange(from: start, to: today)
                for entry in entries {
                    observedDates.insert(entry.date)
                    if entry.doneValue > 0 {
                        completions[entry.date, default: 0] += 1
                    }
                }

                // Lifetime figures come from all history, not this window —
                // the projection needs the real logging rate.
                let allDates = try await LogEntryService.fetchAllDates()
                let distinct = Set(allDates)
                lifetimeLoggedDays = distinct.count
                if let earliest = distinct.min(), let earliestDate = formatter.date(from: earliest) {
                    let span = calendar.dateComponents([.day], from: earliestDate, to: today).day ?? 0
                    lifetimeSpanDays = max(span + 1, 1)
                } else {
                    lifetimeSpanDays = 0
                }
            } catch is CancellationError {
                return
            } catch {
                status = "Couldn't load tides: \(error.localizedDescription)"
                return
            }
        }

        // Fold calendar days onto lunar days, averaging any collisions.
        var totals: [Int: (sum: Int, days: Int)] = [:]
        var observed = 0
        for offset in 0..<Self.windowLength {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let key = formatter.string(from: date)
            // Days with no rows at all are skipped rather than counted as
            // rested — we can't tell "chose not to" from "wasn't using the
            // app yet", and guessing would inflate the rested count.
            guard observedDates.contains(key) else { continue }
            let bin = min(Int(MoonService.lunarAge(date)), Self.lunarBins - 1)
            let existing = totals[bin] ?? (0, 0)
            totals[bin] = (existing.sum + (completions[key] ?? 0), existing.days + 1)
            observed += 1
        }

        observedDays = observed
        bins = (0..<Self.lunarBins).map { bin in
            let entry = totals[bin]
            return LunarBin(
                lunarDay: bin,
                volume: entry.map { Double($0.sum) / Double($0.days) } ?? 0,
                observations: entry?.days ?? 0,
                moonSign: MoonService.sign(dateForLunarDay(bin))
            )
        }
        status = ""
    }
}

/// Two offset swells, drawn rather than illustrated — the empty state
/// should read as the shape a tide makes, not as decoration.
private struct TideGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, amplitudeScale) in [0.42, 0.24].enumerated() {
            let baseline = rect.midY + CGFloat(index) * rect.height * 0.22
            let amplitude = rect.height * amplitudeScale
            path.move(to: CGPoint(x: rect.minX, y: baseline))
            let steps = 60
            for step in 1...steps {
                let progress = CGFloat(step) / CGFloat(steps)
                let x = rect.minX + rect.width * progress
                let y = baseline - sin(progress * .pi * 2 + CGFloat(index) * 0.8) * amplitude / 2
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

#Preview {
    TidesView()
}
