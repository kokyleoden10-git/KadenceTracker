import Foundation

/// Lunar phase and moon sign without an ephemeris dependency.
///
/// Phase uses the mean synodic cycle from a known new moon, which stays
/// within a few hours of truth over decades — far finer than the day-level
/// granularity Tides displays.
///
/// Moon sign uses Meeus's low-precision longitude formula (~0.3° error).
/// Signs are 30° wide, so that's comfortably accurate except within a few
/// hours of a cusp, where a day may be attributed to the neighbouring
/// sign. Acceptable for background context; not acceptable for the natal
/// chart, which is why that is still user-entered.
///
/// Retrogrades are deliberately absent — station/direction genuinely needs
/// real ephemeris data, and guessing would be worse than omitting it.
enum MoonService {
    static let synodicMonth = 29.530588853

    /// 2000-01-06 18:14 UTC — a well-attested new moon epoch.
    private static let newMoonEpoch: Date = {
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 6
        components.hour = 18
        components.minute = 14
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 947182440)
    }()

    /// Days elapsed since the most recent new moon, 0 up to ~29.53.
    static func lunarAge(_ date: Date) -> Double {
        let elapsed = date.timeIntervalSince(newMoonEpoch) / 86_400
        let age = elapsed.truncatingRemainder(dividingBy: synodicMonth)
        return age < 0 ? age + synodicMonth : age
    }

    /// Fraction of the disc lit, 0 (new) to 1 (full).
    static func illumination(_ date: Date) -> Double {
        (1 - cos(2 * .pi * lunarAge(date) / synodicMonth)) / 2
    }

    enum Phase: String {
        case new = "New"
        case waxingCrescent = "Waxing Crescent"
        case firstQuarter = "First Quarter"
        case waxingGibbous = "Waxing Gibbous"
        case full = "Full"
        case waningGibbous = "Waning Gibbous"
        case lastQuarter = "Last Quarter"
        case waningCrescent = "Waning Crescent"
    }

    static func phase(_ date: Date) -> Phase {
        // Eighths of the cycle, with the four principal phases given a
        // narrow window around their exact instant rather than an eighth
        // each — "Full" should mean full, not "closer to full than not".
        let fraction = lunarAge(date) / synodicMonth
        switch fraction {
        case ..<0.02: return .new
        case ..<0.23: return .waxingCrescent
        case ..<0.27: return .firstQuarter
        case ..<0.48: return .waxingGibbous
        case ..<0.52: return .full
        case ..<0.73: return .waningGibbous
        case ..<0.77: return .lastQuarter
        case ..<0.98: return .waningCrescent
        default: return .new
        }
    }

    /// Meeus low-precision lunar ecliptic longitude, degrees 0..360.
    static func eclipticLongitude(_ date: Date) -> Double {
        let j2000 = Date(timeIntervalSince1970: 946_728_000) // 2000-01-01 12:00 UTC
        let d = date.timeIntervalSince(j2000) / 86_400

        let meanLongitude = 218.316 + 13.176396 * d
        let meanAnomaly = 134.963 + 13.064993 * d
        let longitude = meanLongitude + 6.289 * sin(meanAnomaly * .pi / 180)

        let wrapped = longitude.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    static func sign(_ date: Date) -> ZodiacSign {
        let index = Int(eclipticLongitude(date) / 30) % 12
        return ZodiacSign.allCases[index]
    }
}
