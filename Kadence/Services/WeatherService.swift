import Foundation

struct WeatherBlip {
    let locationLabel: String
    let highF: Int
    let lowF: Int
    let condition: String
}

/// The one place in the app that calls an external service other than
/// Supabase (spec §11, §7) — Open-Meteo, chosen specifically because it
/// needs no API key, so no third-party credential has to live in this app.
/// `provider` is surfaced in the UI (HomeHeaderView) so that call is visible,
/// not silent.
enum WeatherService {
    static let provider = "Open-Meteo"

    static func fetch(for location: String) async throws -> WeatherBlip {
        guard let coords = try await geocode(location) else {
            throw WeatherError.locationNotFound
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(coords.lat)"),
            URLQueryItem(name: "longitude", value: "\(coords.lon)"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weathercode"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)

        guard
            let high = forecast.daily.temperature2mMax.first,
            let low = forecast.daily.temperature2mMin.first,
            let code = forecast.daily.weathercode.first
        else {
            throw WeatherError.noData
        }

        return WeatherBlip(
            locationLabel: shortLabel(from: location),
            highF: Int(high.rounded()),
            lowF: Int(low.rounded()),
            condition: conditionText(for: code)
        )
    }

    /// Autocomplete (and Open-Meteo's own geocoder) tends to return
    /// verbose strings like "Brooklyn, New York, NY, United States" — this
    /// reduces that to "Brooklyn, NY" for display by taking the first
    /// segment plus whichever comma-separated segment looks like a US
    /// state abbreviation (exactly two uppercase letters).
    private static func shortLabel(from raw: String) -> String {
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let city = parts.first else { return raw }
        if let stateAbbreviation = parts.dropFirst().first(where: { $0.count == 2 && $0 == $0.uppercased() }) {
            return "\(city), \(stateAbbreviation)"
        }
        return city
    }

    private static func geocode(_ location: String) async throws -> (lat: Double, lon: Double)? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: location),
            URLQueryItem(name: "count", value: "1"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let result = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        guard let first = result.results?.first else { return nil }
        return (first.latitude, first.longitude)
    }

    private static func conditionText(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55, 56, 57: return "Drizzle"
        case 61, 63, 65, 66, 67: return "Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "—"
        }
    }

    enum WeatherError: Error {
        case locationNotFound
        case noData
    }

    private struct GeocodeResponse: Decodable {
        struct Result: Decodable {
            let latitude: Double
            let longitude: Double
        }
        let results: [Result]?
    }

    private struct ForecastResponse: Decodable {
        struct Daily: Decodable {
            let temperature2mMax: [Double]
            let temperature2mMin: [Double]
            let weathercode: [Int]

            enum CodingKeys: String, CodingKey {
                case temperature2mMax = "temperature_2m_max"
                case temperature2mMin = "temperature_2m_min"
                case weathercode
            }
        }
        let daily: Daily
    }
}
