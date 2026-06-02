//
//  SpotForecastOverviewCard.swift
//  Conatus
//
//  Created by Codex on 02.06.2026.
//

import SwiftUI
import Charts

struct SpotForecastOverviewCard: View {
    let spot: Spot
    @State private var selection: ForecastMetric = .waves

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Label(selection.title, systemImage: selection.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Menu {
                Picker("Forecast metric", selection: $selection) {
                    ForEach(availableMetrics) { metric in
                        Label(metric.title, systemImage: metric.systemImage)
                            .tag(metric)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selection.menuTitle)
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(spot.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .accessibilityLabel("Forecast metric")
        }
        .onChange(of: spot.tide == nil) { _, hasNoTide in
            if hasNoTide, selection == .tide {
                selection = .waves
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .waves:
            wavesContent
        case .tide:
            tideContent
        }
    }

    @ViewBuilder
    private var wavesContent: some View {
        if chartPoints.isEmpty {
            Text("No wave data")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
        } else {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(String(format: "%.1f", peakPoint?.heightMeters ?? 0))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(spot.tint.gradient)
                    .contentTransition(.numericText())
                Text("m")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let peak = peakPoint {
                    peakBadge(peak: peak)
                }
            }

            waveChart
        }
    }

    @ViewBuilder
    private var tideContent: some View {
        if let tide = spot.tide {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: tide.current?.state.systemImage ?? "water.waves")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(spot.tint)
                    .frame(width: 34, height: 34)
                    .glassEffect(.regular, in: .circle)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(tide.current?.state.label ?? "Unknown")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(currentHeightLabel(tide.current))
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if let next = tide.current?.nextExtreme {
                        Text(nextExtremeLabel(next))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)
            }

            if tide.timeline.isEmpty {
                Text("No tide timeline")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                tideChart(tide.timeline)
            }
        } else {
            Text("No tide data")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
        }
    }

    private var waveChart: some View {
        Chart {
            ForEach(chartPoints) { sample in
                AreaMark(
                    x: .value("Hour", sample.date),
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
                    x: .value("Hour", sample.date),
                    y: .value("Height", sample.heightMeters)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(spot.tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            if let now = chartPoints.first?.date {
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .bottom, alignment: .leading, spacing: 4) {
                        Text("Now")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
            }

            if let peak = peakPoint {
                PointMark(
                    x: .value("Hour", peak.date),
                    y: .value("Height", peak.heightMeters)
                )
                .foregroundStyle(spot.tint)
                .symbolSize(80)
                .annotation(position: .top, alignment: .center, spacing: 6) {
                    Text(peakAnnotationLabel(for: peak))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                }
            }
        }
        .chartYScale(domain: 0 ... chartYDomainMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                    .font(.caption2)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 200)
    }

    private func tideChart(_ samples: [TideSample]) -> some View {
        Chart(samples) { sample in
            AreaMark(
                x: .value("Time", sample.timestamp),
                y: .value("Sea level", sample.seaLevelHeightMeters ?? 0)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [spot.tint.opacity(0.28), spot.tint.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", sample.timestamp),
                y: .value("Sea level", sample.seaLevelHeightMeters ?? 0)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(spot.tint)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartYScale(domain: tideYDomain(for: samples))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                    .font(.caption2)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 200)
        .accessibilityLabel("Tide timeline for the next twenty four hours")
    }

    private func peakBadge(peak: ChartWavePoint) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.caption2.weight(.bold))
                Text(relativePeakLabel(for: peak.date))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(spot.tint)

            Text(peakTimeLabel(for: peak.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var availableMetrics: [ForecastMetric] {
        spot.tide == nil ? [.waves] : [.waves, .tide]
    }

    private var chartPoints: [ChartWavePoint] {
        if !spot.forecastSlots.isEmpty {
            return spot.forecastSlots.compactMap { slot in
                guard let height = slot.waveHeightMeters else { return nil }
                return ChartWavePoint(
                    date: slot.startTime,
                    heightMeters: height,
                    periodSeconds: slot.wavePeriodSeconds ?? 0
                )
            }
        }

        return spot.hourlyWaves.map {
            ChartWavePoint(
                date: $0.hour,
                heightMeters: $0.heightMeters,
                periodSeconds: $0.periodSeconds
            )
        }
    }

    private var peakPoint: ChartWavePoint? {
        chartPoints.max(by: { $0.heightMeters < $1.heightMeters })
    }

    private var chartYDomainMax: Double {
        let peak = peakPoint?.heightMeters ?? 0
        return max(1.0, peak * 1.25)
    }

    private func relativePeakLabel(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let interval = date.timeIntervalSinceNow
        if interval <= 60 { return "Peaking now" }
        return "Peak " + formatter.localizedString(fromTimeInterval: interval)
    }

    private func peakTimeLabel(for date: Date) -> String {
        let time = date.formatted(.dateTime.hour().minute())
        let qualifier = Calendar.current.isDateInToday(date) ? "Today" : "Tomorrow"
        return "\(time) · \(qualifier)"
    }

    private func peakAnnotationLabel(for peak: ChartWavePoint) -> String {
        let time = peak.date.formatted(.dateTime.hour().minute())
        let qualifier = Calendar.current.isDateInToday(peak.date) ? "Today" : "Tomorrow"
        return "\(String(format: "%.1f", peak.heightMeters)) m  ·  \(time) \(qualifier)"
    }

    private func currentHeightLabel(_ current: TideCurrent?) -> String {
        guard let height = current?.seaLevelHeightMeters else { return "MSL" }
        return String(format: "%.2f m MSL", height)
    }

    private func nextExtremeLabel(_ extreme: TideExtreme) -> String {
        let time = extreme.timestamp.formatted(.dateTime.hour().minute())
        let height = extreme.seaLevelHeightMeters.map { String(format: "%.2f m", $0) } ?? "unknown height"
        return "Next \(extreme.type.label.lowercased()) \(time) · \(height)"
    }

    private func tideYDomain(for samples: [TideSample]) -> ClosedRange<Double> {
        let values = samples.compactMap(\.seaLevelHeightMeters)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return -1 ... 1
        }
        if minValue == maxValue {
            return (minValue - 0.2) ... (maxValue + 0.2)
        }
        let padding = max(0.05, (maxValue - minValue) * 0.18)
        return (minValue - padding) ... (maxValue + padding)
    }

    private enum ForecastMetric: String, Identifiable, CaseIterable {
        case waves
        case tide

        var id: String { rawValue }

        var title: String {
            switch self {
            case .waves: return "Waves"
            case .tide: return "Tide"
            }
        }

        var menuTitle: String {
            switch self {
            case .waves: return "Waves"
            case .tide: return "Tide"
            }
        }

        var systemImage: String {
            switch self {
            case .waves: return "water.waves"
            case .tide: return "arrow.up.and.down"
            }
        }
    }

    private struct ChartWavePoint: Identifiable {
        var id: Date { date }
        let date: Date
        let heightMeters: Double
        let periodSeconds: Double
    }
}
