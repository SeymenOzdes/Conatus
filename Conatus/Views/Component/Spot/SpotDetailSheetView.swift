//
//  SpotDetailSheetView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 23.04.2026.
//

import SwiftUI
import Charts

struct SpotDetailSheetView: View {
    let spot: Spot
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            metricsRow
            waveSection
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(spot.name)
                .font(.title3.weight(.semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(.circle)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: 10) {
            MetricChip(
                symbol: "thermometer.medium",
                primary: "\(Int(round(spot.waterTempC)))°",
                secondary: "Water",
                tint: spot.tint
            )
            WindChip(wind: spot.wind, tint: spot.tint)
        }
    }

    // MARK: - Wave chart
    //wave section uikit ile özel chart yapılmalı!!!!
    private var waveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Waves — next 12 h")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(maxHeightLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Chart(spot.hourlyWaves) { sample in
                BarMark(
                    x: .value("Hour", sample.hour, unit: .hour),
                    y: .value("Height", sample.heightMeters)
                )
                .foregroundStyle(spot.tint.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let height = value.as(Double.self) {
                            Text("\(height, specifier: "%.1f") m")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 130)
        }
    }

    private var maxHeightLabel: String {
        let peak = spot.hourlyWaves.map(\.heightMeters).max() ?? 0
        return String(format: "peak %.1f m", peak)
    }
}

// MARK: - Chips

private struct MetricChip: View {
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
    }
}

private struct WindChip: View {
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
    }

    private func compass(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int((normalized + 22.5) / 45) % 8
        return points[index]
    }
}

#Preview {
    ZStack {
        Color.cyan.opacity(0.3).ignoresSafeArea()
        VStack {
            Spacer()
            SpotDetailSheetView(spot: Spot.samples[0], onClose: {})
                .padding(16)
        }
    }
}
