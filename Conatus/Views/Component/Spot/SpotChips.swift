//
//  SpotChips.swift
//  Conatus
//
//  Created by Seymen Özdeş on 26.04.2026.
//

import SwiftUI

struct MetricChip: View {
    let symbol: String
    let primary: String
    let secondary: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(primary)
                    .font(.system(size: 17, weight: .semibold))
                Text(secondary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(secondary) \(primary)")
    }
}

struct WindChip: View {
    let wind: Wind
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .rotationEffect(.degrees(wind.directionDegrees))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Int(round(wind.speedKmh))) km/h")
                    .font(.system(size: 17, weight: .semibold))
                Text("\(compass(wind.directionDegrees)) wind")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wind \(Int(round(wind.speedKmh))) kilometers per hour, \(compass(wind.directionDegrees))")
    }
}

struct WeatherChip: View {
    let weather: Weather
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: weather.condition.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Int(round(weather.airTempC)))°")
                    .font(.system(size: 17, weight: .semibold))
                Text(weather.condition.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Air \(Int(round(weather.airTempC))) degrees, \(weather.condition.label)")
    }
}

struct WaveHeightChip: View {
    let height: Double
    let tint: Color
    var label: String = "Wave"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "water.waves")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%.1f m", height))
                    .font(.system(size: 17, weight: .semibold))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(String(format: "%.1f", height)) meters")
    }
}

fileprivate func compass(_ degrees: Double) -> String {
    let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
        .truncatingRemainder(dividingBy: 360)
    let index = Int((normalized + 22.5) / 45) % 8
    return points[index]
}
