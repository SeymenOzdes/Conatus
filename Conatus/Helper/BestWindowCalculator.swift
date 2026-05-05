//
//  BestWindowCalculator.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import Foundation

enum BestWindowCalculator {
    /// Score a sliding 3-hour window across each spot's hourlyWaves and pick the best.
    /// Score = avgHeight × avgPeriod × windPenalty, where windPenalty rolls off above ~30 km/h.
    // TODO: replace with 7-day forecast fetch — Spot.samples currently models ~12 hours starting from now.
    static func compute(from spots: [Spot]) -> BestWindow? {
        guard !spots.isEmpty else { return nil }

        var best: (window: BestWindow, score: Double)?

        for spot in spots {
            let waves = spot.hourlyWaves
            guard waves.count >= 3 else { continue }

            let windPenalty = max(0, 1 - spot.wind.speedKmh / 30)

            for start in 0...(waves.count - 3) {
                let slice = Array(waves[start..<(start + 3)])
                let avgHeight = slice.map(\.heightMeters).reduce(0, +) / 3
                let avgPeriod = slice.map(\.periodSeconds).reduce(0, +) / 3
                let score = avgHeight * avgPeriod * windPenalty

                guard score > (best?.score ?? -1) else { continue }

                let candidate = BestWindow(
                    spotID: spot.id,
                    spotName: spot.name,
                    weekday: weekdayLabel(for: slice[0].hour),
                    startHour: slice[0].hour,
                    endHour: slice[2].hour,
                    waveHeightMeters: avgHeight,
                    periodSeconds: avgPeriod,
                    windSpeedKmh: spot.wind.speedKmh,
                    summaryText: summary(
                        spotName: spot.name,
                        avgHeight: avgHeight,
                        avgPeriod: avgPeriod,
                        windSpeed: spot.wind.speedKmh
                    )
                )
                best = (candidate, score)
            }
        }
        return best?.window
    }

    // MARK: - Helpers

    private static func summary(
        spotName: String,
        avgHeight: Double,
        avgPeriod: Double,
        windSpeed: Double
    ) -> String {
        let feet = avgHeight * 3.281
        let windDescription: String
        switch windSpeed {
        case ..<10: windDescription = "light winds"
        case ..<20: windDescription = "moderate winds"
        default:    windDescription = "strong winds"
        }
        return String(format: "%.1f ft @ %ds with %@ at %@",
                      feet, Int(avgPeriod), windDescription, spotName)
    }

    private static func weekdayLabel(for date: Date) -> String {
        // Stub until real 7-day forecast: bucket by time-of-day band.
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:  return "this morning"
        case 12..<17: return "this afternoon"
        case 17..<21: return "this evening"
        default:      return "tonight"
        }
    }
}
