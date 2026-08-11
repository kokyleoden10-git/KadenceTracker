import SwiftUI

/// Replaces streaks (Cosmic Container spec §2). A missed day is a low
/// tide — present in the shape, never marked as a failure. No chain, no
/// best-run, no red.
///
/// The X axis is the lunar cycle rather than "day 1 to 30" (Analytics spec
/// §2). 30 calendar days is almost exactly one synodic month (29.53), so
/// the window tiles the axis roughly once; where two calendar days land on
/// the same lunar day their volumes average — which is also the behaviour
/// wanted later, when several cycles of history fold onto this same axis.
///
/// Background blocks mark the lunar days when the transiting moon is in a
/// sign the natal chart actually occupies, rather than tinting every sign.
/// That keeps the background sparse and makes it mean something: the
/// blocks are the closest thing to a real transit the app can compute
/// without an ephemeris.
struct TidesView: View {
    private static let lunarBins = 30

    /// Roughly seven months — past the pattern threshold, so the sample
    /// shows the unlocked state and several cycles folded together.
    private static let sampleDays = 213

    /// Cycles of history before a lunar reading could mean anything. Lunar
    /// rhythm has to be separated from the weekly rhythm habits already
    /// have, and that takes several full cycles — six is the floor.
    private static let cyclesNeededForCorrelation = 6

    /// Loaded from Supabase like everything else — this used to read a
    /// SwiftData @Query, which went stale the moment charts moved and made a
    /// configured chart look unset.
    @State private var chart: RemoteNatalChart?

    @State private var bins: [LunarBin] = []
    @State private var observedDays = 0
    @State private var restedDayCount = 0
    @State private var lifetimeLoggedDays = 0
    @State private var lifetimeSpanDays = 0
    /// Lunar days that have a card logged. Draws are not habit completions,
    /// so they never feed the wave's volume — they're marked alongside it.
    @State private var drawLunarDays: Set<Int> = []
    @State private var drawDayCount = 0
    @State private var status = "Loading\u{2026}"

    /// Still here only because there isn't enough real history to see the
    /// wave at all yet. In-memory, never written. Delete once there is.
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

    /// Cycles of history folded onto the axis — what you're actually
    /// looking at when a bin averages several days.
    private var cyclesFolded: Double {
        Double(observedDays) / MoonService.synodicMonth
    }

    /// Which natal bodies sit in each sign, so a transiting moon can be
    /// reported as crossing something specific.
    private var occupants: [ZodiacSign: [String]] {
        chart?.placements.occupants ?? [:]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    moonContext

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
                        chartBody
                        phaseAxis
                        crossings
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
            if observedDays > 0 {
                Text(cyclesFolded < 1.5
                     ? "\(observedDays) days logged"
                     : String(format: "%.1f cycles folded together \u{00B7} %d days logged", cyclesFolded, observedDays))
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
            }
        }
    }

    /// Today's sky, stated plainly — phase, sign, element, and whether the
    /// moon is currently crossing anything of yours.
    private var moonContext: some View {
        let today = Date()
        let sign = MoonService.sign(today)
        let signElement = element(of: sign)
        let lunarDay = Int(MoonService.lunarAge(today)) + 1
        let crossing = occupants[sign] ?? []

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                MoonPhaseGlyph(illumination: MoonService.illumination(today))
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(MoonService.phase(today).rawValue) \u{00B7} \(Int((MoonService.illumination(today) * 100).rounded()))% lit")
                        .font(KadenceTheme.bodyFontSemibold(14))
                        .foregroundStyle(KadenceTheme.textPrimary)
                    Text("Moon in \(sign.displayName) \u{00B7} \(signElement.displayName) \u{00B7} lunar day \(lunarDay)")
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.textMuted)
                }
            }

            if !crossing.isEmpty {
                Text("Crossing your \(list(crossing)).")
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(tint(for: sign, opacity: 1))
                    .fixedSize(horizontal: false, vertical: true)
            } else if chart == nil {
                Text("Set up your chart in Draw to see what the moon is crossing.")
                    .font(KadenceTheme.bodyFont(12))
                    .foregroundStyle(KadenceTheme.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KadenceTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty state

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
                Text(drawDayCount > 0
                     ? "The tide is built from habits, not draws — you have \(drawDayCount == 1 ? "1 day" : "\(drawDayCount) days") of cards logged, but no habits yet. Add one on Today and the shape starts to show."
                     : "Log a few days and the shape starts to show. Nothing here counts against you.")
                    .font(KadenceTheme.bodyFont(13))
                    .foregroundStyle(KadenceTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Chart

    private var chartBody: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                natalCrossingBlocks(in: proxy.size)
                quarterMarkers(in: proxy.size)
                waterMarks(in: proxy.size)
            }
        }
        .frame(height: 170)
    }

    /// Only signs the chart occupies get a block, weighted by how much sits
    /// there — so a stellium reads as a broad band and an empty sign as
    /// plain background. Replaces tinting all twelve, which turned the
    /// backdrop into muddy stripes.
    private func natalCrossingBlocks(in size: CGSize) -> some View {
        let binWidth = size.width / CGFloat(Self.lunarBins)
        return ForEach(bins) { bin in
            let count = occupants[bin.moonSign]?.count ?? 0
            if count > 0 {
                Rectangle()
                    .fill(tint(for: bin.moonSign, opacity: opacity(forOccupants: count)))
                    .frame(width: binWidth, height: size.height)
                    .offset(x: CGFloat(bin.lunarDay) * binWidth)
            }
        }
    }

    private func opacity(forOccupants count: Int) -> Double {
        switch count {
        case 1: return 0.10
        case 2: return 0.15
        default: return 0.22
        }
    }

    private func tint(for sign: ZodiacSign, opacity: Double) -> Color {
        switch element(of: sign) {
        case .water: return KadenceTheme.piscesTeal.opacity(opacity)
        case .fire: return KadenceTheme.ariesEmber.opacity(opacity)
        case .air: return KadenceTheme.aquariusIce.opacity(opacity)
        case .earth: return KadenceTheme.capricornBronze.opacity(opacity)
        }
    }

    private func quarterMarkers(in size: CGSize) -> some View {
        ForEach([0.0, 0.25, 0.5, 0.75], id: \.self) { fraction in
            Rectangle()
                .fill(KadenceTheme.textMuted.opacity(0.18))
                .frame(width: 1, height: size.height)
                .offset(x: size.width * fraction)
        }
    }

    /// Flat translucent fill rather than a gradient ramp — the background
    /// blocks are what should carry meaning here, and a gradient competed
    /// with them.
    private func waterMarks(in size: CGSize) -> some View {
        let points = wavePoints(in: size)
        return ZStack {
            smoothPath(through: points, closingIn: size)
                .fill(KadenceTheme.piscesSeafoam.opacity(0.16))
            smoothPath(through: points, closingIn: nil)
                .stroke(KadenceTheme.piscesSeafoam, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// Only observed bins become vertices — an unobserved lunar day must
    /// not be drawn as a zero, which would fabricate a trough.
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

    /// Astronomy plus the chart — no behavioural claim, so this needs no
    /// data threshold. It's what the shaded blocks mean, in words.
    private var crossings: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(crossingRuns, id: \.label) { run in
                HStack(alignment: .top, spacing: 6) {
                    Rectangle()
                        .fill(tint(for: run.sign, opacity: 1))
                        .frame(width: 3, height: 12)
                        .padding(.top, 2)
                    Text(run.label)
                        .font(KadenceTheme.bodyFont(11))
                        .foregroundStyle(KadenceTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private struct CrossingRun {
        let sign: ZodiacSign
        let label: String
    }

    /// Consecutive lunar days sharing an occupied sign, collapsed into one
    /// entry — the moon spends ~2.3 days per sign, so per-day rows would
    /// just repeat.
    private var crossingRuns: [CrossingRun] {
        var runs: [CrossingRun] = []
        var index = 0
        while index < bins.count {
            let sign = bins[index].moonSign
            var end = index
            while end + 1 < bins.count, bins[end + 1].moonSign == sign { end += 1 }

            if let bodies = occupants[sign], !bodies.isEmpty {
                let span = index == end ? "Day \(index + 1)" : "Days \(index + 1)\u{2013}\(end + 1)"
                runs.append(CrossingRun(
                    sign: sign,
                    label: "\(span) \u{00B7} moon in \(sign.displayName) \u{00B7} your \(list(bodies))"
                ))
            }
            index = end + 1
        }
        return runs
    }

    // MARK: - Insights

    private var insights: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(observedDays) days logged \u{00B7} \(restedDayCount) rested")
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

    private var waitingDescription: String {
        let neededDays = Int((Double(Self.cyclesNeededForCorrelation) * MoonService.synodicMonth).rounded())
        let remaining = max(neededDays - lifetimeLoggedDays, 0)

        guard lifetimeLoggedDays > 0, lifetimeSpanDays > 0 else {
            return "Readings need about \(neededDays) logged days \u{2014} six lunar cycles, enough to tell a moon rhythm from an ordinary weekly one. Keep logging and this will estimate when."
        }

        let rate = min(max(Double(lifetimeLoggedDays) / Double(lifetimeSpanDays), 0.01), 1)
        return "\(lifetimeLoggedDays) of about \(neededDays) logged days \u{2014} six lunar cycles, enough to tell a moon rhythm from an ordinary weekly one. At your pace so far, roughly \(humanDuration(Double(remaining) / rate)) to go."
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

        let waxing = bins.filter { $0.hasData && $0.lunarDay < Self.lunarBins / 2 }
        let waning = bins.filter { $0.hasData && $0.lunarDay >= Self.lunarBins / 2 }
        if !waxing.isEmpty, !waning.isEmpty {
            let waxingMean = waxing.reduce(0) { $0 + $1.volume } / Double(waxing.count)
            let waningMean = waning.reduce(0) { $0 + $1.volume } / Double(waning.count)
            let waxingDays = waxing.reduce(0) { $0 + $1.observations }
            let waningDays = waning.reduce(0) { $0 + $1.observations }
            lines.append(String(
                format: "Waxing days averaged %.1f across %d days; waning %.1f across %d.",
                waxingMean, waxingDays, waningMean, waningDays
            ))
        }

        // Which occupied sign coincided with the fullest days. Still
        // descriptive — it reports what happened, not why.
        let crossingBins = bins.filter { $0.hasData && !(occupants[$0.moonSign] ?? []).isEmpty }
        if !crossingBins.isEmpty {
            let byMean = Dictionary(grouping: crossingBins, by: \.moonSign)
                .mapValues { group in
                    group.reduce(0.0) { $0 + $1.volume } / Double(group.count)
                }
            if let best = byMean.max(by: { $0.value < $1.value }) {
                let dayCount = crossingBins.filter { $0.moonSign == best.key }.reduce(0) { $0 + $1.observations }
                lines.append(String(
                    format: "Highest with the moon in %@ (your %@): %.1f across %d days.",
                    best.key.displayName, list(occupants[best.key] ?? []), best.value, dayCount
                ))
            }
        }
        return lines
    }

    private func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }

    private func dateForLunarDay(_ lunarDay: Int) -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        let delta = lunarDay - Int(MoonService.lunarAge(today))
        return Calendar.current.date(byAdding: .day, value: delta, to: today) ?? today
    }

    // MARK: - Load

    private func load() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Completions drive volume, but *any* row makes a day observed — a
        // day where everything was marked not-done is a deliberate low
        // tide and must not vanish from the denominator.
        var completions: [String: Int] = [:]
        var observedDates: Set<String> = []

        if showSample {
            // Randomised each load, with a fabricated mild lunar lean so the
            // folded axis has something to show. The lean is invented — do
            // not read meaning into its shape.
            for offset in 0..<Self.sampleDays {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                let key = formatter.string(from: date)
                observedDates.insert(key)

                if Double.random(in: 0...1) < 0.12 {
                    completions[key] = 0
                    continue
                }
                let fraction = MoonService.lunarAge(date) / MoonService.synodicMonth
                let lean = 1 + 0.45 * sin(2 * .pi * (fraction - 0.25))
                let value = 3.0 * lean + Double.random(in: -1.4...1.4)
                completions[key] = max(Int(value.rounded()), 0)
            }
        } else {
            do {
                for entry in try await LogEntryService.fetchAll() {
                    observedDates.insert(entry.date)
                    if entry.doneValue > 0 {
                        completions[entry.date, default: 0] += 1
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                status = "Couldn't load tides: \(error.localizedDescription)"
                return
            }
        }

        // Fold every observed day onto the lunar axis. Bins average across
        // however many cycles exist, so the shape sharpens with history
        // instead of being a single arbitrary month.
        var totals: [Int: (sum: Int, days: Int)] = [:]
        for key in observedDates {
            guard let date = formatter.date(from: key) else { continue }
            let bin = min(Int(MoonService.lunarAge(date)), Self.lunarBins - 1)
            let existing = totals[bin] ?? (0, 0)
            totals[bin] = (existing.sum + (completions[key] ?? 0), existing.days + 1)
        }

        observedDays = observedDates.count
        restedDayCount = observedDates.filter { (completions[$0] ?? 0) == 0 }.count
        lifetimeLoggedDays = observedDates.count
        if let earliest = observedDates.min(), let earliestDate = formatter.date(from: earliest) {
            lifetimeSpanDays = max((calendar.dateComponents([.day], from: earliestDate, to: today).day ?? 0) + 1, 1)
        } else {
            lifetimeSpanDays = 0
        }
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

/// Two offset swells — the empty state should read as the shape a tide
/// makes, not as decoration.
private struct TideGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, amplitudeScale) in [0.42, 0.24].enumerated() {
            let baseline = rect.midY + CGFloat(index) * rect.height * 0.22
            let amplitude = rect.height * amplitudeScale
            path.move(to: CGPoint(x: rect.minX, y: baseline))
            for step in 1...60 {
                let progress = CGFloat(step) / 60
                path.addLine(to: CGPoint(
                    x: rect.minX + rect.width * progress,
                    y: baseline - sin(progress * .pi * 2 + CGFloat(index) * 0.8) * amplitude / 2
                ))
            }
        }
        return path
    }
}

/// Illuminated fraction as a simple disc — a terminator drawn with a
/// circle mask, no imagery.
private struct MoonPhaseGlyph: View {
    let illumination: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(KadenceTheme.textMuted.opacity(0.5), lineWidth: 1)
                Circle()
                    .fill(KadenceTheme.piscesSeafoam.opacity(0.85))
                    .mask(
                        Rectangle()
                            .frame(width: size * illumination, height: size)
                            .offset(x: -size * (1 - illumination) / 2)
                    )
            }
            .frame(width: size, height: size)
        }
    }
}

#Preview {
    TidesView()
}
