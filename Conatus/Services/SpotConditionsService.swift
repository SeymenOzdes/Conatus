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

    struct TideInfo: Decodable {
        struct Current: Decodable {
            let timestamp: String
            let seaLevelHeightM: Double?
            let state: String
            let nextExtreme: Extreme?

            enum CodingKeys: String, CodingKey {
                case timestamp, state
                case seaLevelHeightM = "sea_level_height_m"
                case nextExtreme = "next_extreme"
            }
        }

        struct Extreme: Decodable {
            let timestamp: String
            let type: String
            let seaLevelHeightM: Double?

            enum CodingKeys: String, CodingKey {
                case timestamp, type
                case seaLevelHeightM = "sea_level_height_m"
            }
        }

        struct Sample: Decodable {
            let timestamp: String
            let seaLevelHeightM: Double?
            let state: String

            enum CodingKeys: String, CodingKey {
                case timestamp, state
                case seaLevelHeightM = "sea_level_height_m"
            }
        }

        let current: Current?
        let timeline: [Sample]
    }

    struct ForecastSlot: Decodable {
        let startTimestamp: String
        let endTimestamp: String
        let partOfDay: String
        let waveHeightM: Double?
        let wavePeriodS: Double?
        let swellDirectionDeg: Double?
        let windSpeedKmh: Double?
        let windDirectionDeg: Double?
        let precipitationMm: Double?
        let weatherCode: Int?
        let tideState: String
        let score: Int
        let verdict: String

        enum CodingKeys: String, CodingKey {
            case startTimestamp = "start_timestamp"
            case endTimestamp = "end_timestamp"
            case partOfDay = "part_of_day"
            case waveHeightM = "wave_height_m"
            case wavePeriodS = "wave_period_s"
            case swellDirectionDeg = "swell_direction_deg"
            case windSpeedKmh = "wind_speed_kmh"
            case windDirectionDeg = "wind_direction_deg"
            case precipitationMm = "precipitation_mm"
            case weatherCode = "weather_code"
            case tideState = "tide_state"
            case score, verdict
        }
    }

    struct BestWindow: Decodable {
        let partOfDay: String
        let startTimestamp: String
        let endTimestamp: String
        let score: Int
        let verdict: String
        let summary: String

        enum CodingKeys: String, CodingKey {
            case partOfDay = "part_of_day"
            case startTimestamp = "start_timestamp"
            case endTimestamp = "end_timestamp"
            case score, verdict, summary
        }
    }

    let spotId: String
    let fetchedAt: String
    let conditions: Current?
    let hourly: [Hourly]
    let tide: TideInfo?
    let forecastSlots: [ForecastSlot]
    let bestWindows: [BestWindow]
    let error: String?

    enum CodingKeys: String, CodingKey {
        case spotId = "spot_id"
        case fetchedAt = "fetched_at"
        case forecastSlots = "forecast_slots"
        case bestWindows = "best_windows"
        case conditions, hourly, tide, error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spotId = try container.decode(String.self, forKey: .spotId)
        fetchedAt = try container.decode(String.self, forKey: .fetchedAt)
        conditions = try container.decodeIfPresent(Current.self, forKey: .conditions)
        hourly = try container.decodeIfPresent([Hourly].self, forKey: .hourly) ?? []
        tide = try container.decodeIfPresent(TideInfo.self, forKey: .tide)
        forecastSlots = try container.decodeIfPresent([ForecastSlot].self, forKey: .forecastSlots) ?? []
        bestWindows = try container.decodeIfPresent([BestWindow].self, forKey: .bestWindows) ?? []
        error = try container.decodeIfPresent(String.self, forKey: .error)
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
            tide: makeTideSnapshot(),
            forecastSlots: makeForecastSlots(),
            bestWindows: makeBestWindows(),
            subtitle: subtitle,
            isPlaceholder: false
        )
    }

    private func makeHourlyWaves() -> [WaveSample] {
        return hourly.prefix(12).compactMap { slot -> WaveSample? in
            guard let height = slot.waveHeightM else { return nil }
            let date = parseDate(slot.timestamp) ?? Date()
            return WaveSample(
                hour: date,
                heightMeters: height,
                periodSeconds: slot.wavePeriodS ?? 0,
                directionDegrees: slot.swellDirectionDeg ?? 0
            )
        }
    }

    private func makeTideSnapshot() -> TideSnapshot? {
        guard let tide else { return nil }

        let current = tide.current.flatMap { dto -> TideCurrent? in
            guard let date = parseDate(dto.timestamp) else { return nil }
            return TideCurrent(
                timestamp: date,
                seaLevelHeightMeters: dto.seaLevelHeightM,
                state: TideState(rawValue: dto.state) ?? .unknown,
                nextExtreme: dto.nextExtreme.flatMap(makeTideExtreme)
            )
        }

        let timeline = tide.timeline.compactMap { sample -> TideSample? in
            guard let date = parseDate(sample.timestamp) else { return nil }
            return TideSample(
                timestamp: date,
                seaLevelHeightMeters: sample.seaLevelHeightM,
                state: TideState(rawValue: sample.state) ?? .unknown
            )
        }

        guard current != nil || !timeline.isEmpty else { return nil }
        return TideSnapshot(current: current, timeline: timeline)
    }

    private func makeTideExtreme(_ dto: SpotConditionsDTO.TideInfo.Extreme) -> TideExtreme? {
        guard let date = parseDate(dto.timestamp),
              let type = TideExtremeType(rawValue: dto.type) else {
            return nil
        }
        return TideExtreme(
            timestamp: date,
            type: type,
            seaLevelHeightMeters: dto.seaLevelHeightM
        )
    }

    private func makeForecastSlots() -> [SurfForecastSlot] {
        forecastSlots.compactMap { slot -> SurfForecastSlot? in
            guard let start = parseDate(slot.startTimestamp),
                  let end = parseDate(slot.endTimestamp) else {
                return nil
            }
            return SurfForecastSlot(
                startTime: start,
                endTime: end,
                partOfDay: SurfDaypart(rawValue: slot.partOfDay) ?? .night,
                waveHeightMeters: slot.waveHeightM,
                wavePeriodSeconds: slot.wavePeriodS,
                swellDirectionDegrees: slot.swellDirectionDeg,
                windSpeedKmh: slot.windSpeedKmh,
                windDirectionDegrees: slot.windDirectionDeg,
                precipitationMm: slot.precipitationMm,
                weatherCode: slot.weatherCode,
                tideState: TideState(rawValue: slot.tideState) ?? .unknown,
                score: slot.score,
                verdict: SurfSlotVerdict(rawValue: slot.verdict) ?? .skip
            )
        }
    }

    private func makeBestWindows() -> [SurfBestWindow] {
        bestWindows.compactMap { window -> SurfBestWindow? in
            guard let start = parseDate(window.startTimestamp),
                  let end = parseDate(window.endTimestamp) else {
                return nil
            }
            return SurfBestWindow(
                partOfDay: SurfDaypart(rawValue: window.partOfDay) ?? .night,
                startTime: start,
                endTime: end,
                score: window.score,
                verdict: SurfSlotVerdict(rawValue: window.verdict) ?? .skip,
                summary: window.summary
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

    private func parseDate(_ string: String) -> Date? {
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

        return formatter.date(from: string)
            ?? fallbackFormatter.date(from: string)
            ?? localFormatter.date(from: string)
    }
}
