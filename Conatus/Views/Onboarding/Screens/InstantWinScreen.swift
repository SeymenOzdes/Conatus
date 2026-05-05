//
//  InstantWinScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct InstantWinScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingScaffold(
            icon: "sparkles",
            title: "Your best window\nthis week",
            progress: (state.currentStep, state.totalSteps),
            canGoBack: false,
            onBack: nil,
            ctaTitle: ctaTitle,
            ctaEnabled: true,
            onCTA: { state.next() },
            secondaryCTA: ("Skip — go to dashboard", { state.next() })
        ) {
            Group {
                if let window = state.bestWindow {
                    BestWindowCard(window: window)
                } else {
                    BestWindowEmptyCard()
                }
            }
        }
        .onAppear {
            if state.bestWindow == nil {
                state.bestWindow = computeWindow()
            }
        }
    }

    private var ctaTitle: String {
        state.bestWindow == nil ? "Go to dashboard" : "Set an Alert for This Window"
    }

    private func computeWindow() -> BestWindow? {
        let pinned = Spot.samples.filter { state.pinnedSpotIDs.contains($0.id) }
        let candidates = pinned.isEmpty ? Spot.samples : pinned
        return BestWindowCalculator.compute(from: candidates)
    }
}

// MARK: - Card

struct BestWindowCard: View {
    let window: BestWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            metrics
            Text(window.summaryText)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(window.spotName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(window.weekday.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text(timeRange)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.18)))
        }
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            MetricTile(
                icon: "water.waves",
                value: String(format: "%.1f ft", window.waveHeightMeters * 3.281),
                label: "Waves"
            )
            MetricTile(
                icon: "metronome",
                value: "\(Int(window.periodSeconds))s",
                label: "Period"
            )
            MetricTile(
                icon: "wind",
                value: "\(Int(window.windSpeedKmh)) km/h",
                label: "Wind"
            )
        }
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let start = formatter.string(from: window.startHour).lowercased()
        let end = formatter.string(from: window.endHour).lowercased()
        return "\(start)–\(end)"
    }
}

private struct MetricTile: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct BestWindowEmptyCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Forecast unavailable")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("Once forecast data syncs, your best window appears here.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
