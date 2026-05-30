//
//  SpotDetailSecondaryStatsGrid.swift
//  Conatus
//
//  Created by Codex on 31.05.2026.
//

import SwiftUI

struct SpotDetailSecondaryStatsGrid: View {
    let spot: Spot

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                infoTile(symbol: "metronome", label: "Avg period", value: "\(Int(round(spot.detailAveragePeriodSeconds))) s")
                infoTile(symbol: "wind", label: "Wind gust", value: "\(Int(round(spot.wind.gustKmh))) km/h")
            }
            GridRow {
                infoTile(symbol: "arrow.down.right", label: "Drop after peak", value: String(format: "%.1f m", spot.detailDropAfterPeakMeters))
                infoTile(symbol: "thermometer.medium", label: "Sea temp", value: "\(Int(round(spot.waterTempC)))°")
            }
        }
    }

    private func infoTile(symbol: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(spot.tint)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}
