//
//  SpotDetailMetricsRow.swift
//  Conatus
//
//  Created by Codex on 31.05.2026.
//

import SwiftUI

struct SpotDetailMetricsRow: View {
    let spot: Spot

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                WeatherChip(weather: spot.weather, tint: spot.tint)
                MetricChip(
                    symbol: "thermometer.medium",
                    primary: "\(Int(round(spot.waterTempC)))°",
                    secondary: "Water",
                    tint: spot.tint
                )
                WindChip(wind: spot.wind, tint: spot.tint)
                WaveHeightChip(height: spot.currentWaveHeight, tint: spot.tint, label: "Wave")
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }
}

