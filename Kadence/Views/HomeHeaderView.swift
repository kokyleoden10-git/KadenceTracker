import SwiftUI

/// Spec §11 — personalized title, date + weather blip, rotating quote.
/// Presentational only; no new tables beyond what auth already added.
struct HomeHeaderView: View {
    let profile: Profile?

    @State private var weather: WeatherBlip?
    @State private var weatherStatus: String?

    private var title: String {
        if let nickname = profile?.nickname, !nickname.isEmpty {
            return "\(nickname)'s Kadence"
        }
        return "Kadence"
    }

    private var quote: Quotes.Quote { Quotes.forToday() }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KadenceTheme.displayFont(32))
                .foregroundStyle(KadenceTheme.textPrimary)

            HStack(spacing: 4) {
                Text(Date(), style: .date)
                if let weather {
                    Text("| \(weather.locationLabel) | High \(weather.highF)\u{00B0} \u{00B7} Low \(weather.lowF)\u{00B0} \u{00B7} \(weather.condition)")
                } else if let weatherStatus {
                    Text("| \(weatherStatus)")
                }
            }
            .font(KadenceTheme.bodyFont(13))
            .foregroundStyle(KadenceTheme.textMuted)

            if weather != nil {
                Text("via \(WeatherService.provider)")
                    .font(KadenceTheme.bodyFont(11))
                    .foregroundStyle(KadenceTheme.textMuted.opacity(0.7))
            }

            Text("\u{201C}\(quote.text)\u{201D} \u{2014} \(quote.source)")
                .font(KadenceTheme.bodyFont(13))
                .italic()
                .foregroundStyle(KadenceTheme.textMuted)
                .padding(.top, 4)
        }
        .task(id: profile?.currentLocation) {
            // No Settings screen exists yet to set current_location, so
            // there's nothing actionable to nudge the user toward — just
            // omit the weather line entirely until that's built.
            guard let location = profile?.currentLocation, !location.isEmpty else {
                weatherStatus = nil
                return
            }
            do {
                weather = try await WeatherService.fetch(for: location)
            } catch {
                weatherStatus = "weather unavailable"
            }
        }
    }
}

#Preview {
    ZStack {
        KadenceTheme.bg.ignoresSafeArea()
        HomeHeaderView(profile: nil).padding()
    }
}
