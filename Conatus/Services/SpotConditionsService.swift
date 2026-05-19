import CoreLocation
import Foundation

struct SpotConditionsDTO: Decodable {
    struct Current: Decodable {
        let timestamp: String
        let airTempC: Double?
        let waterTempC: Double?
        let waveHeightM: Double?
        let wavePeriodS: Double?
        let waveDirectionDeg: Double?
        let windSpeedKmh: Double?
        let windGustKmh: Double?
        let windDirectionDeg: Double?
        let weatherCode: Int?

        enum CodingKeys: String, CodingKey {
            case timestamp
            case airTempC = "air_temp_c"
            case waterTempC = "water_temp_c"
            case waveHeightM = "wave_height_m"
            case wavePeriodS = "wave_period_s"
            case waveDirectionDeg = "wave_direction_deg"
            case windSpeedKmh = "wind_speed_kmh"
            case windGustKmh = "wind_gust_kmh"
            case windDirectionDeg = "wind_direction_deg"
            case weatherCode = "weather_code"
        }
    }

    struct Hourly: Decodable {
        let timestamp: String
        let waveHeightM: Double?
        let wavePeriodS: Double?
        let swellDirectionDeg: Double?
        let windSpeedKmh: Double?
        let windDirectionDeg: Double?
        let precipitationMm: Double?
        let weatherCode: Int?

        enum CodingKeys: String, CodingKey {
            case timestamp
            case waveHeightM = "wave_height_m"
            case wavePeriodS = "wave_period_s"
            case swellDirectionDeg = "swell_direction_deg"
            case windSpeedKmh = "wind_speed_kmh"
            case windDirectionDeg = "wind_direction_deg"
            case precipitationMm = "precipitation_mm"
            case weatherCode = "weather_code"
        }
    }

    let spotId: String
    let fetchedAt: String
    let conditions: Current?
    let hourly: [Hourly]
    let error: String?

    enum CodingKeys: String, CodingKey {
        case spotId = "spot_id"
        case fetchedAt = "fetched_at"
        case conditions, hourly, error
    }
}

enum SpotConditionsServiceError: Error {
    case invalidURL
    case badStatus(Int)
    case decoding(Error)
    case transport(Error)
}

struct SpotConditionsService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchConditions(spotId: String) async throws -> SpotConditionsDTO {
        let path = "/v1/spots/\(spotId)/conditions"
        guard let url = URL(string: path, relativeTo: SearchService.baseURL)?.absoluteURL else {
            throw SpotConditionsServiceError.invalidURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw SpotConditionsServiceError.transport(error)
        }

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw SpotConditionsServiceError.badStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(SpotConditionsDTO.self, from: data)
        } catch {
            throw SpotConditionsServiceError.decoding(error)
        }
    }
}

extension SpotConditionsDTO {
    /// Builds a Spot from a real conditions payload. Returns nil for the
    /// inland / no-marine-coverage case so callers can leave the placeholder
    /// in place rather than rendering a Spot full of zeros.
    func makeSpot(from result: SpotResult) -> Spot? {
        guard let current = conditions else { return nil }

        let coordinate = CLLocationCoordinate2D(latitude: result.lat, longitude: result.lng)
        let (symbol, tint) = Spot.appearance(for: result.breakType)
        let subtitle = Spot.subtitle(from: result)

        let weather = Weather(
            airTempC: current.airTempC ?? 0,
            condition: weatherCondition(from: current.weatherCode)
        )
        let wind = Wind(
            speedKmh: current.windSpeedKmh ?? 0,
            directionDegrees: current.windDirectionDeg ?? 0,
            gustKmh: current.windGustKmh ?? 0
        )

        return Spot(
            name: result.name,
            coordinate: coordinate,
            symbol: symbol,
            tint: tint,
            waterTempC: current.waterTempC ?? 0,
            weather: weather,
            wind: wind,
            hourlyWaves: makeHourlyWaves(),
            subtitle: subtitle,
            isPlaceholder: false
        )
    }

    private func makeHourlyWaves() -> [WaveSample] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let localFormatter: DateFormatter = {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .iso8601)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd'T'HH:mm"
            f.timeZone = TimeZone.current
            return f
        }()

        return hourly.prefix(12).compactMap { slot -> WaveSample? in
            guard let height = slot.waveHeightM else { return nil }
            let date = formatter.date(from: slot.timestamp)
                ?? fallbackFormatter.date(from: slot.timestamp)
                ?? localFormatter.date(from: slot.timestamp)
                ?? Date()
            return WaveSample(
                hour: date,
                heightMeters: height,
                periodSeconds: slot.wavePeriodS ?? 0,
                directionDegrees: slot.swellDirectionDeg ?? 0
            )
        }
    }

    private func weatherCondition(from code: Int?) -> WeatherCondition {
        guard let code else { return .clear }
        switch code {
        case 0: return .clear
        case 1, 2: return .partlyCloudy
        case 3, 45, 48: return .cloudy
        case 51...67, 80...82, 95...99: return .rainy
        case 71...77, 85, 86: return .cloudy
        default: return .clear
        }
    }
}

