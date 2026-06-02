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
    private var currentSpotID: UUID?
    private var lastRecommendation: SurfRecommendation?
    private var refreshVariant = 0

    func generate(for spot: Spot, forceRefresh: Bool = false) async {
        task?.cancel()
        guard !spot.hourlyWaves.isEmpty || !spot.forecastSlots.isEmpty else {
            phase = .unavailable(Self.unavailableRecommendation(for: spot))
            task = nil
            return
        }

        if currentSpotID != spot.id {
            currentSpotID = spot.id
            lastRecommendation = nil
            refreshVariant = 0
        } else if forceRefresh {
            refreshVariant += 1
        }

        let variant = refreshVariant
        phase = .loading
        let newTask = Task { [weak self] in
            guard let self else { return }
            await self.run(spot: spot, variant: variant)
        }
        task = newTask
        await newTask.value
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
        currentSpotID = nil
        lastRecommendation = nil
        refreshVariant = 0
    }

    private func run(spot: Spot, variant: Int) async {
        guard !spot.hourlyWaves.isEmpty || !spot.forecastSlots.isEmpty else {
            phase = .unavailable(Self.unavailableRecommendation(for: spot))
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(200))
        } catch {
            return
        }

        guard case .available = SystemLanguageModel.default.availability else {
            let recommendation = distinctRecommendation(
                Self.fallbackRecommendation(for: spot, variant: variant),
                spot: spot,
                variant: variant
            )
            phase = .unavailable(recommendation)
            lastRecommendation = recommendation
            return
        }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: Self.prompt(for: spot, variant: variant),
                generating: SurfRecommendation.self
            )
            try Task.checkCancellation()
            let recommendation = distinctRecommendation(
                Self.normalizedRecommendation(from: response.content, spot: spot, variant: variant),
                spot: spot,
                variant: variant
            )
            phase = .ready(recommendation)
            lastRecommendation = recommendation
        } catch is CancellationError {
            // Superseded by a newer request; let it drive the next state.
        } catch {
            let recommendation = distinctRecommendation(
                Self.fallbackRecommendation(for: spot, variant: variant),
                spot: spot,
                variant: variant
            )
            phase = .failed(recommendation)
            lastRecommendation = recommendation
        }
    }

    private func distinctRecommendation(
        _ recommendation: SurfRecommendation,
        spot: Spot,
        variant: Int
    ) -> SurfRecommendation {
        guard variant > 0, recommendation == lastRecommendation else {
            return recommendation
        }
        return Self.fallbackRecommendation(for: spot, variant: variant)
    }

    private static let instructions = """
    You are a practical surf coach. Given a single spot's 24-hour surf forecast,
    return a structured, forecast-specific recommendation for a recreational surfer.

    ALWAYS pick a best window — even on SKIP, pick the LEAST-BAD hours
    (the relatively better part of the forecast). Exclude only the very
    worst hours from that window. Never return "none" or empty.

    The summary must include concrete forecast details, not a generic vibe check:
    mention the best timing plus at least two measurable factors such as wave
    height, period, wind, tide, water temperature, air temperature, or weather.

    Return exactly 3 short reasons. Each reason must be based only on the
    provided forecast and should name a measurable surf factor. Avoid generic
    phrases like "conditions look good" unless they are backed by a metric.
    Use plain sentences, stable wording, and no markdown. Keep the summary
    under 36 words and the action under 18 words. English only.
    """

    private static func prompt(for spot: Spot, variant: Int) -> String {
        var lines: [String] = [
            "Spot: \(spot.name)",
            "Now: water \(Int(round(spot.waterTempC)))°C, air \(Int(round(spot.weather.airTempC)))°C, \(spot.weather.condition.label)",
            "Wind: \(Int(round(spot.wind.speedKmh))) km/h gusting \(Int(round(spot.wind.gustKmh))) km/h from \(cardinal(from: spot.wind.directionDegrees)) (\(Int(round(spot.wind.directionDegrees)))°)"
        ]

        if variant > 0 {
            lines.append("Refresh request \(variant): keep the same forecast facts, but use fresh wording and emphasize \(refreshFocus(for: variant)). Do not repeat prior phrasing.")
        }

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

    private static func refreshFocus(for variant: Int) -> String {
        switch variant % 3 {
        case 1:
            return "timing and the best paddle-out window"
        case 2:
            return "wind, tide, and cleanup risk"
        default:
            return "wave size, period, and session decision"
        }
    }

    private static func fallbackRecommendation(for spot: Spot, variant: Int = 0) -> SurfRecommendation {
        normalizedRecommendation(from: nil, spot: spot, variant: variant)
    }

    private static func normalizedRecommendation(from generated: SurfRecommendation?, spot: Spot, variant: Int = 0) -> SurfRecommendation {
        guard let snapshot = conditionSnapshot(for: spot) else {
            return unavailableRecommendation(for: spot)
        }

        guard let generated else {
            return canonicalRecommendation(for: snapshot, variant: variant)
        }

        let summary = cleaned(generated.summary)
        let bestWindow = generated.bestWindow.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = cleaned(generated.action)
        let canonicalReasons = canonicalReasons(for: snapshot, variant: variant)
        let reasons = generated.reasons
            .map(cleaned)
            .filter { isQualityReason($0) }

        return SurfRecommendation(
            verdict: isVerdictAligned(generated.verdict, with: snapshot) ? generated.verdict : snapshot.verdict,
            summary: isQualitySummary(summary) ? summary : canonicalSummary(for: snapshot, variant: variant),
            bestWindow: isUsableBestWindow(bestWindow) ? bestWindow : snapshot.bestWindow,
            confidence: isConfidenceAligned(generated.confidence, with: snapshot) ? generated.confidence : snapshot.confidence,
            reasons: qualityReasons(from: reasons, canonicalReasons: canonicalReasons),
            action: isQualityAction(action) ? action : canonicalAction(for: snapshot, variant: variant)
        )
    }

    private static func canonicalRecommendation(for snapshot: ConditionSnapshot, variant: Int = 0) -> SurfRecommendation {
        SurfRecommendation(
            verdict: snapshot.verdict,
            summary: canonicalSummary(for: snapshot, variant: variant),
            bestWindow: snapshot.bestWindow,
            confidence: snapshot.confidence,
            reasons: canonicalReasons(for: snapshot, variant: variant),
            action: canonicalAction(for: snapshot, variant: variant)
        )
    }

    private static func isUsableBestWindow(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return !value.isEmpty
            && lowered != "none"
            && lowered != "n/a"
            && lowered != "unknown"
    }

    private static func cleaned(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isQualitySummary(_ value: String) -> Bool {
        wordCount(in: value) >= 12
            && wordCount(in: value) <= 42
            && forecastSignalCount(in: value) >= 2
            && !isGeneric(value)
    }

    private static func isQualityReason(_ value: String) -> Bool {
        wordCount(in: value) >= 5
            && forecastSignalCount(in: value) >= 1
            && !isGeneric(value)
    }

    private static func isQualityAction(_ value: String) -> Bool {
        wordCount(in: value) >= 4
            && wordCount(in: value) <= 20
            && !isGeneric(value)
    }

    private static func qualityReasons(from generated: [String], canonicalReasons: [String]) -> [String] {
        var resolved: [String] = []
        for reason in generated + canonicalReasons where !resolved.contains(reason) {
            resolved.append(reason)
            if resolved.count == 3 { break }
        }
        return resolved
    }

    private static func isVerdictAligned(_ verdict: SurfVerdict, with snapshot: ConditionSnapshot) -> Bool {
        verdict == snapshot.verdict
            || snapshot.confidence == .low
            || (verdict == .maybe && snapshot.verdict != .maybe)
            || (snapshot.verdict == .maybe && verdict != .maybe)
    }

    private static func isConfidenceAligned(_ confidence: SurfConfidence, with snapshot: ConditionSnapshot) -> Bool {
        confidence == snapshot.confidence
            || snapshot.confidence == .medium
            || confidence == .medium
    }

    private static func forecastSignalCount(in value: String) -> Int {
        let lowered = value.lowercased()
        let signals = [
            "wave", "swell", "period", "wind", "gust", "tide", "water",
            "air", "weather", "km/h", "degrees"
        ]
        var count = signals.reduce(0) { count, signal in
            lowered.contains(signal) ? count + 1 : count
        }
        if value.contains(where: \.isNumber) {
            count += 1
        }
        if lowered.contains("°c") || lowered.contains(" c") {
            count += 1
        }
        if lowered.contains(":") {
            count += 1
        }
        return count
    }

    private static func isGeneric(_ value: String) -> Bool {
        let lowered = value.lowercased()
        let genericPhrases = [
            "looks good",
            "looks decent",
            "looks fun",
            "good conditions",
            "decent conditions",
            "fun conditions",
            "worth checking",
            "check it out",
            "could be good"
        ]
        return genericPhrases.contains { lowered.contains($0) }
    }

    private static func wordCount(in value: String) -> Int {
        value.split(whereSeparator: \.isWhitespace).count
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

    private static func canonicalSummary(for snapshot: ConditionSnapshot, variant: Int = 0) -> String {
        let variantIndex = variant % 3
        switch snapshot.verdict {
        case .go:
            switch variantIndex {
            case 1:
                return "Aim for \(snapshot.bestWindow): the peak sits near \(snapshot.peakHeightLabel) m at \(timeLabel(for: snapshot.peak.hour)), with \(snapshot.periodLabel)s period and \(snapshot.windLabel) km/h wind supporting a session."
            case 2:
                return "The call is strongest around \(snapshot.bestWindow), when \(snapshot.peakHeightLabel) m waves pair with \(snapshot.periodLabel)s period and wind stays near \(snapshot.windLabel) km/h."
            default:
                return "Best window is \(snapshot.bestWindow) as waves reach \(snapshot.peakHeightLabel) m near \(timeLabel(for: snapshot.peak.hour)), period averages \(snapshot.periodLabel)s, and wind sits near \(snapshot.windLabel) km/h."
            }
        case .maybe:
            switch variantIndex {
            case 1:
                return "Time it around \(snapshot.bestWindow): waves touch \(snapshot.peakHeightLabel) m near \(timeLabel(for: snapshot.peak.hour)), but \(snapshot.windLabel) km/h wind and \(snapshot.periodLabel)s period keep it conditional."
            case 2:
                return "The window worth watching is \(snapshot.bestWindow), with \(snapshot.peakHeightLabel) m surf, \(snapshot.periodLabel)s period, and wind near \(snapshot.windLabel) km/h adding some uncertainty."
            default:
                return "Usable window is \(snapshot.bestWindow), with \(snapshot.peakHeightLabel) m waves near \(timeLabel(for: snapshot.peak.hour)), \(snapshot.periodLabel)s period, and \(snapshot.windLabel) km/h wind making timing important."
            }
        case .skip:
            switch variantIndex {
            case 1:
                return "If you check it, use \(snapshot.bestWindow): the best pulse is only \(snapshot.peakHeightLabel) m near \(timeLabel(for: snapshot.peak.hour)), with \(snapshot.windLabel) km/h wind and \(snapshot.periodLabel)s period."
            case 2:
                return "The least-bad option is \(snapshot.bestWindow), but \(snapshot.peakHeightLabel) m waves, \(snapshot.periodLabel)s period, and \(snapshot.windLabel) km/h wind point toward a pass."
            default:
                return "Least-bad window is \(snapshot.bestWindow), but waves only reach \(snapshot.peakHeightLabel) m near \(timeLabel(for: snapshot.peak.hour)) with \(snapshot.windLabel) km/h wind and \(snapshot.periodLabel)s period."
            }
        }
    }

    private static func canonicalReasons(for snapshot: ConditionSnapshot, variant: Int = 0) -> [String] {
        let base = [
            "Peak wave around \(snapshot.peakHeightLabel) m near \(timeLabel(for: snapshot.peak.hour)).",
            "Average period holds near \(snapshot.periodLabel) s with \(snapshot.tideLabel).",
            "Wind is \(snapshot.windLabel) km/h and water is \(snapshot.waterLabel)°C."
        ]
        let alternates = [
            "Best timing centers on \(snapshot.bestWindow).",
            "Air is \(Int(round(snapshot.airTempC)))°C with \(snapshot.weatherLabel.lowercased()) weather.",
            "Gusts are near \(Int(round(snapshot.windGustKmh))) km/h, so watch surface texture."
        ]

        switch variant % 3 {
        case 1:
            return [base[0], alternates[0], base[2]]
        case 2:
            return [base[1], alternates[2], alternates[1]]
        default:
            return base
        }
    }

    private static func canonicalAction(for snapshot: ConditionSnapshot, variant: Int = 0) -> String {
        switch snapshot.verdict {
        case .go:
            switch variant % 3 {
            case 1: return "Target the cleanest part of the window."
            case 2: return "Go while the peak and wind line up."
            default: return "Paddle during the peak window."
            }
        case .maybe:
            switch variant % 3 {
            case 1: return "Check wind before committing."
            case 2: return "Keep it flexible and time the window."
            default: return "Go only if the wind settles."
            }
        case .skip:
            switch variant % 3 {
            case 1: return "Only paddle if local checks improve."
            case 2: return "Wait for more size or cleaner wind."
            default: return "Save the session for a cleaner pulse."
            }
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
