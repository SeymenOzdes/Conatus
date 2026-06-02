//
//  SpotForecastSlotsCard.swift
//  Conatus
//
//  Created by Codex on 02.06.2026.
//

import SwiftUI

struct SpotForecastSlotsCard: View {
    let spot: Spot

    var body: some View {
        if !spot.forecastSlots.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                header
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(spot.forecastSlots) { slot in
                            slotCard(slot)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label("24h forecast", systemImage: "clock")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let best = spot.bestWindows.first {
                Text("\(best.partOfDay.label) \(timeRange(best.startTime, best.endTime))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(spot.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private func slotCard(_ slot: SurfForecastSlot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeRange(slot.startTime, slot.endTime))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(slot.partOfDay.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                Text(slot.verdict.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(slot.verdict.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(slot.verdict.color.opacity(0.12), in: .capsule)
            }

            VStack(alignment: .leading, spacing: 8) {
                stat("water.waves", waveLabel(slot))
                stat("metronome", periodLabel(slot))
                stat("wind", windLabel(slot))
                stat(slot.tideState.systemImage, "\(slot.tideState.label) tide")
            }

            ProgressView(value: Double(slot.score), total: 100)
                .tint(slot.verdict.color)
                .accessibilityLabel("Surf score \(slot.score)")
        }
        .padding(14)
        .frame(width: 178, height: 178, alignment: .topLeading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(timeRange(slot.startTime, slot.endTime)), \(slot.verdict.label), \(waveLabel(slot)), \(windLabel(slot)), \(slot.tideState.label) tide")
    }

    private func stat(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(spot.tint)
                .frame(width: 15)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        "\(start.formatted(.dateTime.hour()))-\(end.formatted(.dateTime.hour()))"
    }

    private func waveLabel(_ slot: SurfForecastSlot) -> String {
        guard let height = slot.waveHeightMeters else { return "No wave data" }
        return String(format: "%.1f m waves", height)
    }

    private func periodLabel(_ slot: SurfForecastSlot) -> String {
        guard let period = slot.wavePeriodSeconds else { return "No period" }
        return "\(Int(round(period))) s period"
    }

    private func windLabel(_ slot: SurfForecastSlot) -> String {
        guard let wind = slot.windSpeedKmh else { return "No wind" }
        return "\(Int(round(wind))) km/h wind"
    }
}

