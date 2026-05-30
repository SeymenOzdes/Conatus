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
        guard !spot.hourlyWaves.isEmpty else {
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
            phase = .ready(response.content)
        } catch is CancellationError {
            // Superseded by a newer request; let it drive the next state.
        } catch {
            phase = .failed(Self.fallbackRecommendation(for: spot))
        }
    }

    private static let instructions = """
    You are a concise surf coach. Given a single spot's 12-hour forecast,
    return a structured recommendation for a recreational surfer.

    ALWAYS pick a best window — even on SKIP, pick the LEAST-BAD hours
    (the relatively better part of the forecast). Exclude only the very
    worst hours from that window. Never return "none" or empty.

    Return exactly 2 or 3 short reasons. Base them only on the provided
    forecast: wave height, period, wind, water temperature, air temperature,
    and weather. Keep the summary under 36 words and the action under 18 words.
    No markdown. No emojis. English only.
    """

    private static func prompt(for spot: Spot) -> String {
        var lines: [String] = [
            "Spot: \(spot.name)",
            "Now: water \(Int(round(spot.waterTempC)))°C, air \(Int(round(spot.weather.airTempC)))°C, \(spot.weather.condition.label)",
            "Wind: \(Int(round(spot.wind.speedKmh))) km/h gusting \(Int(round(spot.wind.gustKmh))) km/h from \(cardinal(from: spot.wind.directionDegrees)) (\(Int(round(spot.wind.directionDegrees)))°)"
        ]

        let window = Array(spot.hourlyWaves.prefix(12))
        if !window.isEmpty {
            lines.append("Hourly forecast (next \(window.count) hours):")
            for sample in window {
                let time = sample.hour.formatted(.dateTime.hour().minute())
                let height = String(format: "%.2f", sample.heightMeters)
                let period = Int(round(sample.periodSeconds))
                lines.append("  \(time) — wave \(height) m, period \(period) s")
            }

            if let peak = spot.peakWave,
               let peakIndex = window.firstIndex(where: { $0.id == peak.id }) {
                let peakTime = peak.hour.formatted(.dateTime.hour().minute())
                let peakHeight = String(format: "%.2f", peak.heightMeters)
                lines.append("Peak: \(peakHeight) m at \(peakTime) (hour \(peakIndex + 1) of \(window.count))")
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
        let window = Array(spot.hourlyWaves.prefix(12))
        guard !window.isEmpty else {
            return unavailableRecommendation(for: spot)
        }

        let peak = window.max(by: { $0.heightMeters < $1.heightMeters }) ?? window[0]
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

        let peakHeight = String(format: "%.1f", peak.heightMeters)
        let period = Int(round(averagePeriod))
        let wind = Int(round(windSpeed))
        let water = Int(round(spot.waterTempC))

        return SurfRecommendation(
            verdict: verdict,
            summary: summary(for: verdict, peakHeight: peakHeight, peak: peak),
            bestWindow: bestWindowLabel(in: window),
            confidence: confidence,
            reasons: [
                "Peak wave around \(peakHeight) m near \(timeLabel(for: peak.hour)).",
                "Average period holds near \(period) s.",
                "Wind is \(wind) km/h with \(water) degrees water."
            ],
            action: action(for: verdict)
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

    private static func summary(for verdict: SurfVerdict, peakHeight: String, peak: WaveSample) -> String {
        switch verdict {
        case .go:
            return "The best pulse reaches \(peakHeight) m around \(timeLabel(for: peak.hour)), with enough period to justify a session."
        case .maybe:
            return "There is a usable window around \(timeLabel(for: peak.hour)), but the setup is mixed and worth timing carefully."
        case .skip:
            return "Conditions look weak or messy, with the least-bad window near \(timeLabel(for: peak.hour))."
        }
    }

    private static func action(for verdict: SurfVerdict) -> String {
        switch verdict {
        case .go:
            return "Paddle during the peak window."
        case .maybe:
            return "Go only if the wind settles."
        case .skip:
            return "Save the session for a cleaner pulse."
        }
    }

    private static func bestWindowLabel(in samples: [WaveSample]) -> String {
        guard let peak = samples.max(by: { $0.heightMeters < $1.heightMeters }),
              let peakIndex = samples.firstIndex(where: { $0.id == peak.id }) else {
            return "Check local reports"
        }

        let start = samples[max(0, peakIndex - 1)].hour
        let end = samples[min(samples.count - 1, peakIndex + 1)].hour
        if Calendar.current.isDate(start, equalTo: end, toGranularity: .hour) {
            return timeLabel(for: start)
        }
        return "\(timeLabel(for: start))-\(timeLabel(for: end))"
    }

    private static func timeLabel(for date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}

@Generable
struct SurfRecommendation: Equatable {
    @Guide(description: "Overall verdict for the next 12 hours.")
    let verdict: SurfVerdict

    @Guide(description: "A practical 1 sentence take for a recreational surfer, max 36 words. No emojis, no markdown.")
    let summary: String

    @Guide(description: "Best window to paddle out, formatted as a single clock time '14:00' or a range '14:00-16:00'. Pick the relatively-best hours from the forecast; required even when verdict is SKIP. Never empty, never 'none'.")
    let bestWindow: String

    @Guide(description: "Confidence in this recommendation.")
    let confidence: SurfConfidence

    @Guide(description: "Exactly 2 or 3 short reasons based only on wave height, period, wind, water temperature, air temperature, or weather. No markdown.")
    let reasons: [String]

    @Guide(description: "A concise action the surfer should take, max 18 words. No emojis, no markdown.")
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
