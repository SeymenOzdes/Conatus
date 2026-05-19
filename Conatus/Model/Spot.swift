//
//  Spot.swift
//  Conatus
//
//  Created by Seymen Özdeş on 23.04.2026.
//

import CoreLocation
import SwiftUI

struct ConditionTag {
    let code: String
    let tint: Color
}

struct Spot: Identifiable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let symbol: String
    let tint: Color
    let waterTempC: Double
    let weather: Weather
    let wind: Wind
    let hourlyWaves: [WaveSample]
    let subtitle: String?
    let conditionTags: [ConditionTag]
    let isPlaceholder: Bool

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        symbol: String,
        tint: Color,
        waterTempC: Double,
        weather: Weather,
        wind: Wind,
        hourlyWaves: [WaveSample],
        subtitle: String? = nil,
        conditionTags: [ConditionTag] = [],
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.symbol = symbol
        self.tint = tint
        self.waterTempC = waterTempC
        self.weather = weather
        self.wind = wind
        self.hourlyWaves = hourlyWaves
        self.subtitle = subtitle
        self.conditionTags = conditionTags
        self.isPlaceholder = isPlaceholder
    }
}

extension Spot {
    /// Builds a Spot from a backend search hit so the existing detail-sheet
    /// plumbing can render before per-spot conditions load.
    static func placeholder(from result: SpotResult) -> Spot {
        let (symbol, tint) = appearance(for: result.breakType)
        return Spot(
            name: result.name,
            coordinate: CLLocationCoordinate2D(latitude: result.lat, longitude: result.lng),
            symbol: symbol,
            tint: tint,
            waterTempC: 0,
            weather: Weather(airTempC: 0, condition: .clear),
            wind: Wind(speedKmh: 0, directionDegrees: 0, gustKmh: 0),
            hourlyWaves: [],
            subtitle: subtitle(from: result),
            isPlaceholder: true
        )
    }

    /// Builds a Spot from a locally saved user spot. Marked `isPlaceholder` so
    /// the detail sheet skips the summarizer and conditions fetch — those rely on
    /// a backend `spotId` that user-created spots don't have.
    static func placeholder(from userSpot: UserSpot) -> Spot {
        let (symbol, tint) = appearance(for: userSpot.breakType)
        let subtitleParts = [userSpot.country, userSpot.breakType.capitalized]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let subtitle = subtitleParts.joined(separator: " · ")
        return Spot(
            id: userSpot.id,
            name: userSpot.name,
            coordinate: CLLocationCoordinate2D(latitude: userSpot.latitude, longitude: userSpot.longitude),
            symbol: symbol,
            tint: tint,
            waterTempC: 0,
            weather: Weather(airTempC: 0, condition: .clear),
            wind: Wind(speedKmh: 0, directionDegrees: 0, gustKmh: 0),
            hourlyWaves: [],
            subtitle: subtitle.isEmpty ? nil : subtitle,
            isPlaceholder: true
        )
    }

    static func appearance(for breakType: String?) -> (String, Color) {
        switch breakType?.lowercased() {
        case "reef":   return ("water.waves", .indigo)
        case "point":  return ("mappin.and.ellipse", .orange)
        case "beach":  return ("beach.umbrella.fill", .teal)
        case "river":  return ("water.waves.and.arrow.trianglehead.down", .cyan)
        default:       return ("figure.surfing", .blue)
        }
    }

    static func subtitle(from result: SpotResult) -> String? {
        let s = [result.country, result.breakType?.capitalized]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return s.isEmpty ? nil : s
    }
}

extension Spot {
    var peakWave: WaveSample? {
        hourlyWaves.max(by: { $0.heightMeters < $1.heightMeters })
    }

    var currentWave: WaveSample? {
        hourlyWaves.first
    }

    var currentWaveHeight: Double {
        currentWave?.heightMeters ?? 0
    }

    enum SurfStatus {
        case firing, good, fair

        var label: String {
            switch self {
            case .firing: return "FIRING"
            case .good:   return "GOOD"
            case .fair:   return "FAIR"
            }
        }

        var color: Color {
            switch self {
            case .firing: return .green
            case .good:   return .cyan
            case .fair:   return .orange
            }
        }
    }

    var surfStatus: SurfStatus {
        let peak = hourlyWaves.prefix(12).map(\.heightMeters).max() ?? 0
        if peak >= 1.2 { return .firing }
        if peak >= 0.6 { return .good }
        return .fair
    }

    func displayedWaveRange(units: UserPreferences.Units) -> String {
        let next12 = hourlyWaves.prefix(12).map(\.heightMeters)
        guard let lo = next12.min(), let hi = next12.max() else { return "—" }
        let loVal: Int
        let hiVal: Int
        let suffix: String
        switch units {
        case .metric:
            loVal = Int(lo.rounded())
            hiVal = Int(hi.rounded())
            suffix = "m"
        case .imperial:
            loVal = Int((lo * 3.28084).rounded())
            hiVal = Int((hi * 3.28084).rounded())
            suffix = "ft"
        }
        return loVal == hiVal ? "\(loVal)\(suffix)" : "\(loVal)\u{2013}\(hiVal)\(suffix)"
    }
}

struct Wind {
    let speedKmh: Double
    let directionDegrees: Double
    let gustKmh: Double
}

struct Weather {
    let airTempC: Double
    let condition: WeatherCondition
}

enum WeatherCondition {
    case clear, partlyCloudy, cloudy, rainy, windy

    var systemImage: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .rainy:        return "cloud.rain.fill"
        case .windy:        return "wind"
        }
    }

    var label: String {
        switch self {
        case .clear:        return "Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy:       return "Cloudy"
        case .rainy:        return "Rainy"
        case .windy:        return "Windy"
        }
    }
}

struct WaveSample: Identifiable {
    let id: UUID
    let hour: Date
    let heightMeters: Double
    let periodSeconds: Double
    let directionDegrees: Double

    init(
        id: UUID = UUID(),
        hour: Date,
        heightMeters: Double,
        periodSeconds: Double,
        directionDegrees: Double = 0
    ) {
        self.id = id
        self.hour = hour
        self.heightMeters = heightMeters
        self.periodSeconds = periodSeconds
        self.directionDegrees = directionDegrees
    }
}

// MARK: - Sample data

extension Spot {
    static let samples: [Spot] = {
        [
            Spot(
                name: "Alaçatı",
                coordinate: .init(latitude: 38.2887, longitude: 26.3778),
                symbol: "figure.surfing",
                tint: .blue,
                waterTempC: 21,
                weather: Weather(airTempC: 24, condition: .windy),
                wind: Wind(speedKmh: 22, directionDegrees: 35, gustKmh: 31),
                hourlyWaves: hourlyWaves(
                    heights: [0.7, 0.8, 1.0, 1.2, 1.3, 1.4, 1.2, 1.1, 0.9, 0.8, 0.7, 0.6],
                    period: 8
                ),
                subtitle: "Turkey · Offshore",
                conditionTags: [
                    ConditionTag(code: "KR", tint: .red),
                    ConditionTag(code: "LF", tint: .green),
                    ConditionTag(code: "TR", tint: .yellow)
                ]
            ),
            Spot(
                name: "Çeşme",
                coordinate: .init(latitude: 38.3238, longitude: 26.3040),
                symbol: "sailboat",
                tint: .teal,
                waterTempC: 22,
                weather: Weather(airTempC: 26, condition: .clear),
                wind: Wind(speedKmh: 14, directionDegrees: 75, gustKmh: 20),
                hourlyWaves: hourlyWaves(
                    heights: [0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.8, 0.7, 0.6, 0.5, 0.5, 0.4],
                    period: 6
                ),
                subtitle: "Turkey · Cross",
                conditionTags: [
                    ConditionTag(code: "KR", tint: .red),
                    ConditionTag(code: "LF", tint: .green),
                    ConditionTag(code: "TR", tint: .yellow),
                    ConditionTag(code: "KM", tint: .red)
                ]
            ),
            Spot(
                name: "Foça",
                coordinate: .init(latitude: 38.6727, longitude: 26.7568),
                symbol: "figure.pool.swim",
                tint: .cyan,
                waterTempC: 20,
                weather: Weather(airTempC: 23, condition: .partlyCloudy),
                wind: Wind(speedKmh: 10, directionDegrees: 270, gustKmh: 15),
                hourlyWaves: hourlyWaves(
                    heights: [0.3, 0.4, 0.5, 0.5, 0.6, 0.6, 0.5, 0.5, 0.4, 0.4, 0.3, 0.3],
                    period: 5
                ),
                subtitle: "Turkey · Light",
                conditionTags: [
                    ConditionTag(code: "KM", tint: .red)
                ]
            ),
        ]
    }()

    private static func hourlyWaves(heights: [Double], period: Double) -> [WaveSample] {
        let calendar = Calendar.current
        let now = calendar.date(bySetting: .minute, value: 0, of: Date()) ?? Date()
        return heights.enumerated().map { index, height in
            let hour = calendar.date(byAdding: .hour, value: index, to: now) ?? now
            return WaveSample(hour: hour, heightMeters: height, periodSeconds: period)
        }
    }
}
