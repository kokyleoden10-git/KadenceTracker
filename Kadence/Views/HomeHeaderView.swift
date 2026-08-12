import SwiftUI

/// Spec §11 header — layout/hierarchy carried over from v1 on request:
/// small-caps label → big date heading → tracked weather line → status
/// line → quote in its own card, in that order, rather than v2's original
/// flat stack of same-weight lines.
struct HomeHeaderView: View {
    let profile: Profile?
    let status: String

    @State private var weather: WeatherBlip?
    @State private var weatherStatus: String?

    private var title: String {
        KadenceTheme.personalizedTitle(nickname: profile?.nickname, screen: "Kadence")
    }

    private var dateHeading: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private var quote: Quotes.Quote { Quotes.forToday() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(KadenceTheme.bodyFontSemibold(12))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(KadenceTheme.textMuted)

            Text(dateHeading)
                .font(KadenceTheme.displayFont(32))
                .foregroundStyle(KadenceTheme.textPrimary)

            if let weather {
                Text("\(weather.locationLabel.uppercased())  |  HIGH \(weather.highF)\u{00B0} \u{00B7} LOW \(weather.lowF)\u{00B0} \u{00B7} \(weather.condition.uppercased())")
                    .font(KadenceTheme.bodyFont(11))
                    .tracking(0.8)
                    .lineSpacing(6)
                    .foregroundStyle(KadenceTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let weatherStatus {
                Text(weatherStatus.uppercased())
                    .font(KadenceTheme.bodyFont(11))
                    .tracking(0.8)
                    .lineSpacing(6)
                    .foregroundStyle(KadenceTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !status.isEmpty {
                Text(status)
                    .font(KadenceTheme.bodyFont(14))
                    .foregroundStyle(KadenceTheme.textMuted)
            }

            Text("\u{201C}\(quote.text)\u{201D}")
                .font(KadenceTheme.bodyFont(15))
                .italic()
                .foregroundStyle(KadenceTheme.textPrimary.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [KadenceTheme.surface, KadenceTheme.bg],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(KadenceTheme.piscesSeafoam.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.top, 4)
        }
        .task(id: profile?.currentLocation) {
            guard let location = profile?.currentLocation, !location.isEmpty else {
                weather = nil
                weatherStatus = nil
                return
            }
            do {
                weather = try await WeatherService.fetch(for: location)
            } catch {
                weather = nil
                weatherStatus = "weather unavailable"
            }
        }
    }
}

#Preview {
    ZStack {
        KadenceTheme.bg.ignoresSafeArea()
        HomeHeaderView(profile: nil, status: "No habits yet.").padding()
    }
}
