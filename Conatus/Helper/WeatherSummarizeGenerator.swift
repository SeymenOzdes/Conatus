//
//  WeatherSummarizeGenerator.swift
//  Conatus
//
//  Created by Seymen Özdeş on 28.04.2026.
//
import Foundation
import SwiftUI
import FoundationModels

@Observable
@MainActor
final class WeatherSummarizeGenerator {
    enum Phase: Equatable {
        case idle
        case loading
        case ready(SurfRecommendation)
        case unavailable(SurfRecommendation)
        case failed(SurfRecommendation)
    }

    private(set) var phase: Phase = .idle

    private var task: Task<Void, Never>?

    func generate(for spot: Spot) async {
        task?.cancel()
        let newTask = Task { [weak self] in
            guard let self else { return }
            await self.run(spot: spot)
        }
        task = newTask
        await newTask.value
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    private func run(spot: Spot) async {
        guard !spot.hourlyWaves.isEmpty || !spot.forecastSlots.isEmpty else {
            phase = .unavailable(Self.unavailableRecommendation(for: spot))
            return
        }

        guard case .available = SystemLanguageModel.default.availability else {
            phase = .unavailable(Self.fallbackRecommendation(for: spot))
            return
        }

        phase = .loading

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: Self.prompt(for: spot),
                generating: SurfRecommendation.self
            )
            try Task.checkCancellation()
            phase = .ready(Self.normalizedRecommendation(from: response.content, spot: spot))
        } catch is CancellationError {
            // Superseded by a newer request; let it drive the next state.
        } catch {
            phase = .failed(Self.fallbackRecommendation(for: spot))
        }
    }

    private static let instructions = """
    You are a concise surf coach. Given a single spot's 24-hour surf forecast,
    return a structured recommendation for a recreational surfer.

    ALWAYS pick a best window — even on SKIP, pick the LEAST-BAD hours
    (the relatively better part of the forecast). Exclude only the very
    worst hours from that window. Never return "none" or empty.

    Return exactly 3 short reasons. Base them only on the provided forecast:
    wave height, period, wind, tide, water temperature, air temperature, and weather.
    Use plain sentences, stable wording, and no markdown. Keep the summary
    under 36 words and the action under 18 words. English only.
    """

    private static func prompt(for spot: Spot) -> String {
        var lines: [String] = [
            "Spot: \(spot.name)",
            "Now: water \(Int(round(spot.waterTempC)))°C, air \(Int(round(spot.weather.airTempC)))°C, \(spot.weather.condition.label)",
            "Wind: \(Int(round(spot.wind.speedKmh))) km/h gusting \(Int(round(spot.wind.gustKmh))) km/h from \(cardinal(from: spot.wind.directionDegrees)) (\(Int(round(spot.wind.directionDegrees)))°)"
        ]

        if let tide = spot.tide?.current {
            lines.append("Tide: \(tide.state.label), \(heightLabel(tide.seaLevelHeightMeters)) MSL")
            if let next = tide.nextExtreme {
                lines.append("Next tide extreme: \(next.type.label) at \(timeLabel(for: next.timestamp)), \(heightLabel(next.seaLevelHeightMeters))")
            }
        }

        if !spot.bestWindows.isEmpty {
            lines.append("Best windows:")
            for window in spot.bestWindows {
                lines.append("  \(window.partOfDay.label) \(timeRangeLabel(window.startTime, window.endTime)) — \(window.verdict.label), score \(window.score), \(window.summary)")
            }
        }

        if !spot.forecastSlots.isEmpty {
            let slots = Array(spot.forecastSlots.prefix(8))
            lines.append("3-hour forecast slots (next \(slots.count * 3) hours):")
            for slot in slots {
                lines.append(
                    "  \(timeRangeLabel(slot.startTime, slot.endTime)) — wave \(heightLabel(slot.waveHeightMeters)), period \(periodLabel(slot.wavePeriodSeconds)), wind \(windLabel(slot.windSpeedKmh)), tide \(slot.tideState.label), verdict \(slot.verdict.label), score \(slot.score)"
                )
            }
        } else {
            let window = Array(spot.hourlyWaves.prefix(12))
            if !window.isEmpty {
                lines.append("Hourly forecast (next \(window.count) hours):")
                for sample in window {
                    let time = timeLabel(for: sample.hour)
                    let height = String(format: "%.2f", sample.heightMeters)
                    let period = Int(round(sample.periodSeconds))
                    lines.append("  \(time) — wave \(height) m, period \(period) s")
                }

                if let peak = spot.peakWave,
                   let peakIndex = window.firstIndex(where: { $0.id == peak.id }) {
                    let peakTime = timeLabel(for: peak.hour)
                    let peakHeight = String(format: "%.2f", peak.heightMeters)
                    lines.append("Peak: \(peakHeight) m at \(peakTime) (hour \(peakIndex + 1) of \(window.count))")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func cardinal(from degrees: Double) -> String {
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((normalized + 22.5) / 45) % 8
        return directions[index]
    }

    private static func fallbackRecommendation(for spot: Spot) -> SurfRecommendation {
        normalizedRecommendation(from: nil, spot: spot)
    }

    private static func normalizedRecommendation(from _: SurfRecommendation?, spot: Spot) -> SurfRecommendation {
        guard let snapshot = conditionSnapshot(for: spot) else {
            return unavailableRecommendation(for: spot)
        }

        return SurfRecommendation(
            verdict: snapshot.verdict,
            summary: canonicalSummary(for: snapshot),
            bestWindow: snapshot.bestWindow,
            confidence: snapshot.confidence,
            reasons: canonicalReasons(for: snapshot),
            action: canonicalAction(for: snapshot)
        )
    }

    private static func conditionSnapshot(for spot: Spot) -> ConditionSnapshot? {
        if !spot.forecastSlots.isEmpty {
            return forecastConditionSnapshot(for: spot)
        }

        let window = Array(spot.hourlyWaves.prefix(12))
        guard !window.isEmpty else {
            return nil
        }

        let peak = window.max(by: { $0.heightMeters < $1.heightMeters }) ?? window[0]
        let peakIndex = window.firstIndex(where: { $0.id == peak.id }) ?? 0
        let averagePeriod = window.map(\.periodSeconds).reduce(0, +) / Double(window.count)
        let windSpeed = spot.wind.speedKmh
        let verdict: SurfVerdict
        let confidence: SurfConfidence

        if peak.heightMeters >= 1.0, averagePeriod >= 7, windSpeed <= 28 {
            verdict = .go
            confidence = .high
        } else if peak.heightMeters >= 0.6, windSpeed <= 36 {
            verdict = .maybe
            confidence = .medium
        } else {
            verdict = .skip
            confidence = windSpeed > 42 || peak.heightMeters < 0.4 ? .high : .low
        }

        return ConditionSnapshot(
            verdict: verdict,
            confidence: confidence,
            peak: peak,
            peakIndex: peakIndex,
            averagePeriodSeconds: averagePeriod,
            windSpeedKmh: windSpeed,
            windGustKmh: spot.wind.gustKmh,
            waterTempC: spot.waterTempC,
            airTempC: spot.weather.airTempC,
            weatherLabel: spot.weather.condition.label,
            tideLabel: tideLabel(for: spot),
            bestWindow: bestWindowLabel(in: window, peakIndex: peakIndex)
        )
    }

    private static func forecastConditionSnapshot(for spot: Spot) -> ConditionSnapshot? {
        let slots = Array(spot.forecastSlots.prefix(8))
        guard let bestSlot = slots.max(by: { $0.score < $1.score }) else {
            return nil
        }

        let peak = WaveSample(
            hour: bestSlot.startTime,
            heightMeters: bestSlot.waveHeightMeters ?? 0,
            periodSeconds: bestSlot.wavePeriodSeconds ?? 0
        )
        let averagePeriod = average(slots.compactMap(\.wavePeriodSeconds))
        let averageWind = average(slots.compactMap(\.windSpeedKmh))
        let bestWindow = spot.bestWindows.first.map {
            timeRangeLabel($0.startTime, $0.endTime)
        } ?? timeRangeLabel(bestSlot.startTime, bestSlot.endTime)

        let verdict: SurfVerdict
        let confidence: SurfConfidence
        switch bestSlot.verdict {
        case .go:
            verdict = .go
            confidence = bestSlot.score >= 82 ? .high : .medium
        case .maybe:
            verdict = .maybe
            confidence = .medium
        case .skip:
            verdict = .skip
            confidence = bestSlot.score < 25 ? .high : .low
        }

        return ConditionSnapshot(
            verdict: verdict,
            confidence: confidence,
            peak: peak,
            peakIndex: 0,
            averagePeriodSeconds: averagePeriod,
            windSpeedKmh: averageWind,
            windGustKmh: spot.wind.gustKmh,
            waterTempC: spot.waterTempC,
            airTempC: spot.weather.airTempC,
            weatherLabel: spot.weather.condition.label,
            tideLabel: tideLabel(for: spot),
            bestWindow: bestWindow
        )
    }

    private static func unavailableRecommendation(for spot: Spot) -> SurfRecommendation {
        SurfRecommendation(
            verdict: .maybe,
            summary: "Marine conditions are not available for this spot yet.",
            bestWindow: "Check local reports",
            confidence: .low,
            reasons: [
                "No hourly wave forecast is available.",
                "AI guidance needs live marine conditions."
            ],
            action: "Use nearby buoys before paddling out."
        )
    }

    private static func canonicalSummary(for snapshot: ConditionSnapshot) -> String {
        switch snapshot.verdict {
        case .go:
            return "The best pulse reaches \(snapshot.peakHeightLabel) m around \(timeLabel(for: snapshot.peak.hour)), with enough period to justify a session."
        case .maybe:
            return "There is a usable window around \(timeLabel(for: snapshot.peak.hour)), but the setup is mixed and worth timing carefully."
        case .skip:
            return "Conditions look weak or messy, with the least-bad window near \(timeLabel(for: snapshot.peak.hour))."
        }
    }

    private static func canonicalReasons(for snapshot: ConditionSnapshot) -> [String] {
        [
            "Peak wave around \(snapshot.peakHeightLabel) m near \(timeLabel(for: snapshot.peak.hour)).",
            "Average period holds near \(snapshot.periodLabel) s with \(snapshot.tideLabel).",
            "Wind is \(snapshot.windLabel) km/h with \(snapshot.waterLabel) degrees water."
        ]
    }

    private static func canonicalAction(for snapshot: ConditionSnapshot) -> String {
        switch snapshot.verdict {
        case .go:
            return "Paddle during the peak window."
        case .maybe:
            return "Go only if the wind settles."
        case .skip:
            return "Save the session for a cleaner pulse."
        }
    }

    private static func bestWindowLabel(in samples: [WaveSample], peakIndex: Int? = nil) -> String {
        guard let peak = samples.max(by: { $0.heightMeters < $1.heightMeters }) else {
            return "Check local reports"
        }

        let resolvedPeakIndex = peakIndex ?? samples.firstIndex(where: { $0.id == peak.id }) ?? 0
        let start = samples[max(0, resolvedPeakIndex - 1)].hour
        let end = samples[min(samples.count - 1, resolvedPeakIndex + 1)].hour
        if Calendar.current.isDate(start, equalTo: end, toGranularity: .hour) {
            return timeLabel(for: start)
        }
        return "\(timeLabel(for: start))-\(timeLabel(for: end))"
    }

    private static func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func timeRangeLabel(_ start: Date, _ end: Date) -> String {
        "\(timeLabel(for: start))-\(timeLabel(for: end))"
    }

    private static func heightLabel(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return String(format: "%.2f m", value)
    }

    private static func periodLabel(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return "\(Int(round(value)))s"
    }

    private static func windLabel(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return "\(Int(round(value))) km/h"
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func tideLabel(for spot: Spot) -> String {
        guard let state = spot.tide?.current?.state else { return "unknown tide" }
        return "\(state.label.lowercased()) tide"
    }

    private struct ConditionSnapshot {
        let verdict: SurfVerdict
        let confidence: SurfConfidence
        let peak: WaveSample
        let peakIndex: Int
        let averagePeriodSeconds: Double
        let windSpeedKmh: Double
        let windGustKmh: Double
        let waterTempC: Double
        let airTempC: Double
        let weatherLabel: String
        let tideLabel: String
        let bestWindow: String

        var peakHeightLabel: String {
            String(format: "%.1f", peak.heightMeters)
        }

        var periodLabel: Int {
            Int(round(averagePeriodSeconds))
        }

        var windLabel: Int {
            Int(round(windSpeedKmh))
        }

        var waterLabel: Int {
            Int(round(waterTempC))
        }
    }
}

@Generable
struct SurfRecommendation: Equatable {
    @Guide(description: "Overall verdict for the next 24 hours.")
    let verdict: SurfVerdict

    @Guide(description: "A practical 1 sentence take for a recreational surfer, max 36 words. Plain text only.")
    let summary: String

    @Guide(description: "Best window to paddle out, formatted only as '14:00' or '14:00-16:00'. Never empty, never 'none'.")
    let bestWindow: String

    @Guide(description: "Confidence in this recommendation.")
    let confidence: SurfConfidence

    @Guide(description: "Exactly 3 short plain-text reasons based only on wave height, period, wind, water temperature, air temperature, or weather.")
    let reasons: [String]

    @Guide(description: "A concise action the surfer should take, max 18 words. Plain text only.")
    let action: String
}

extension SurfRecommendation {
    static let loading = SurfRecommendation(
        verdict: .maybe,
        summary: "Analyzing the next 12 hours for wave shape, wind, and timing.",
        bestWindow: "Finding window",
        confidence: .medium,
        reasons: [
            "Reading the wave trend.",
            "Checking wind against the best hours.",
            "Comparing period and water temperature."
        ],
        action: "Preparing a surf call."
    )

    static let unavailable = SurfRecommendation(
        verdict: .maybe,
        summary: "Marine conditions are not available for this spot yet.",
        bestWindow: "Check local reports",
        confidence: .low,
        reasons: [
            "No hourly wave forecast is available.",
            "AI guidance needs live marine conditions."
        ],
        action: "Use nearby buoys before paddling out."
    )
}

@Generable
enum SurfVerdict: String, Equatable {
    case go = "GO"
    case maybe = "MAYBE"
    case skip = "SKIP"
}

@Generable
enum SurfConfidence: String, Equatable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}
