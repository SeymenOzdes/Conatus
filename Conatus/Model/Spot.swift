//
//  Spot.swift
//  Conatus
//
//  Created by Seymen Özdeş on 23.04.2026.
//

import CoreLocation
import SwiftUI

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

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        symbol: String,
        tint: Color,
        waterTempC: Double,
        weather: Weather,
        wind: Wind,
        hourlyWaves: [WaveSample]
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

    init(id: UUID = UUID(), hour: Date, heightMeters: Double, periodSeconds: Double) {
        self.id = id
        self.hour = hour
        self.heightMeters = heightMeters
        self.periodSeconds = periodSeconds
    }
}

// MARK: - Sample data

extension Spot {
    static var samples: [Spot] {
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
                )
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
                )
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
                )
            ),
        ]
    }

    private static func hourlyWaves(heights: [Double], period: Double) -> [WaveSample] {
        let calendar = Calendar.current
        let now = calendar.date(bySetting: .minute, value: 0, of: Date()) ?? Date()
        return heights.enumerated().map { index, height in
            let hour = calendar.date(byAdding: .hour, value: index, to: now) ?? now
            return WaveSample(hour: hour, heightMeters: height, periodSeconds: period)
        }
    }
}
