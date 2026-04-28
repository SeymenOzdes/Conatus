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
        case failed
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

    private func run(spot: Spot) async {
        guard case .available = SystemLanguageModel.default.availability else {
            phase = .failed
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
            phase = .failed
        }
    }

    private static let instructions = """
    You are a concise surf coach. Given a single spot's 12-hour forecast,
    return a verdict (GO, MAYBE, or SKIP), a short 2 sentence take, and
    Be sure to tell the user the best time window for surfing.

    ALWAYS pick a best window — even on SKIP, pick the LEAST-BAD hours
    (the relatively better part of the forecast). Exclude only the very
    worst hours from that window. Never return "none" or empty.

    Anchor the take on the most notable signal — peak wave height and its
    time, wind quality, or water temp. Keep the summary under 50 words.
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
}

@Generable
struct SurfRecommendation: Equatable {
    @Guide(description: "Overall verdict for the next 12 hours.")
    let verdict: SurfVerdict

    @Guide(description: "A practical 2 sentence take for a recreational surfer, max 60 words. No emojis, no markdown.")
    let summary: String

    @Guide(description: "Best window to paddle out, formatted as a single clock time '14:00' or a range '14:00–16:00'. Pick the relatively-best hours from the forecast — required even when verdict is SKIP. Never empty, never 'none'.")
    let bestWindow: String
}

@Generable
enum SurfVerdict: String, Equatable {
    case go = "GO"
    case maybe = "MAYBE"
    case skip = "SKIP"
}
