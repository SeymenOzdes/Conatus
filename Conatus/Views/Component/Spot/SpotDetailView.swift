//
//  SpotDetailView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 26.04.2026.
//

import SwiftUI
import Charts

struct SpotDetailView: View {
    let spot: Spot
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            content
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                metricsRow
                waveHeroCard
                secondaryGrid
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(.circle)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Metrics row

    private var metricsRow: some View {
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

    // MARK: - Wave hero card

    private var waveHeroCard: some View {
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

    private var focalHeight: Double {
        spot.peakWave?.heightMeters ?? spot.currentWaveHeight
    }

    private var focalNumber: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            Text(String(format: "%.1f", focalHeight))
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
                Text(relativePeakLabel(peak: peak))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(spot.tint)

            Text(peakTimeLabel(peak: peak))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func relativePeakLabel(peak: WaveSample) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let interval = peak.hour.timeIntervalSinceNow
        if interval <= 60 { return "Peaking now" }
        return "Peak " + formatter.localizedString(fromTimeInterval: interval)
    }

    private func peakTimeLabel(peak: WaveSample) -> String {
        let time = peak.hour.formatted(.dateTime.hour().minute())
        let qualifier = Calendar.current.isDateInToday(peak.hour) ? "Today" : "Tomorrow"
        return "\(time) · \(qualifier)"
    }

    // MARK: - Curved wave chart

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
        .chartYScale(domain: 0 ... yDomainMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                    .font(.caption2)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 200)
    }

    private var yDomainMax: Double {
        let peak = spot.peakWave?.heightMeters ?? 0
        return max(1.0, peak * 1.25)
    }

    private func peakAnnotation(peak: WaveSample) -> some View {
        let time = peak.hour.formatted(.dateTime.hour().minute())
        let qualifier = Calendar.current.isDateInToday(peak.hour) ? "Today" : "Tomorrow"
        return Text("\(String(format: "%.1f", peak.heightMeters)) m  ·  \(time) \(qualifier)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Secondary grid

    private var secondaryGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                infoTile(symbol: "metronome", label: "Avg period", value: "\(Int(round(avgPeriod))) s")
                infoTile(symbol: "wind", label: "Wind gust", value: "\(Int(round(spot.wind.gustKmh))) km/h")
            }
            GridRow {
                infoTile(symbol: "arrow.down.right", label: "Drop after peak", value: String(format: "%.1f m", dropAfterPeak))
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

    private var avgPeriod: Double {
        guard !spot.hourlyWaves.isEmpty else { return 0 }
        let total = spot.hourlyWaves.map(\.periodSeconds).reduce(0, +)
        return total / Double(spot.hourlyWaves.count)
    }

    private var dropAfterPeak: Double {
        guard let peak = spot.peakWave,
              let peakIndex = spot.hourlyWaves.firstIndex(where: { $0.id == peak.id }) else {
            return 0
        }
        let after = spot.hourlyWaves.dropFirst(peakIndex + 1)
        guard let lowest = after.map(\.heightMeters).min() else { return 0 }
        return max(0, peak.heightMeters - lowest)
    }
}

#Preview {
    SpotDetailView(spot: Spot.samples[0], onClose: {})
}
