//
//  SpotWaveHeroCard.swift
//  Conatus
//
//  Created by Codex on 31.05.2026.
//

import SwiftUI
import Charts

struct SpotWaveHeroCard: View {
    let spot: Spot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Waves", systemImage: "water.waves")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Next 12 hours")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            if spot.hourlyWaves.isEmpty {
                Text("No data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else {
                focalNumber
                waveChart
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var focalNumber: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            Text(String(format: "%.1f", spot.detailFocalWaveHeight))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(spot.tint.gradient)
                .contentTransition(.numericText())
            Text("m")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let peak = spot.peakWave {
                peakBadge(peak: peak)
            }
        }
    }

    private func peakBadge(peak: WaveSample) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.caption2.weight(.bold))
                Text(spot.detailRelativePeakLabel(for: peak))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(spot.tint)

            Text(spot.detailPeakTimeLabel(for: peak))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var waveChart: some View {
        Chart {
            ForEach(spot.hourlyWaves) { sample in
                AreaMark(
                    x: .value("Hour", sample.hour),
                    y: .value("Height", sample.heightMeters)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [spot.tint.opacity(0.55), spot.tint.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Hour", sample.hour),
                    y: .value("Height", sample.heightMeters)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(spot.tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            if let now = spot.currentWave?.hour {
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .bottom, alignment: .leading, spacing: 4) {
                        Text("Now")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
            }

            if let peak = spot.peakWave {
                PointMark(
                    x: .value("Hour", peak.hour),
                    y: .value("Height", peak.heightMeters)
                )
                .foregroundStyle(spot.tint)
                .symbolSize(80)
                .annotation(position: .top, alignment: .center, spacing: 6) {
                    peakAnnotation(peak: peak)
                }
            }
        }
        .chartYScale(domain: 0 ... spot.detailChartYDomainMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                    .font(.caption2)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 200)
    }

    private func peakAnnotation(peak: WaveSample) -> some View {
        Text(spot.detailPeakAnnotationLabel(for: peak))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
    }
}
