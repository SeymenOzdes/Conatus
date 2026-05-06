//
//  HomeContentView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 06.05.2026.
//

import SwiftUI

@Observable
@MainActor
final class HomeViewModel {
    private(set) var primarySpot: Spot
    private(set) var bestWindow: BestWindow?
    private(set) var greetingName: String?
    let summarizer = WeatherSummarizeGenerator()

    init() {
        self.primarySpot = Self.resolvePrimarySpot()
        self.bestWindow = Self.computeBestWindow()
        self.greetingName = Self.resolveGreetingName()
    }

    func refresh() {
        let next = Self.resolvePrimarySpot()
        let primaryChanged = next.id != primarySpot.id
        primarySpot = next
        bestWindow = Self.computeBestWindow()
        greetingName = Self.resolveGreetingName()
        if primaryChanged { summarizer.cancel() }
    }

    func loadSummary() async {
        await summarizer.generate(for: primarySpot)
    }

    func cancelSummary() {
        summarizer.cancel()
    }

    private static func resolvePrimarySpot() -> Spot {
        let prefs = UserPreferences.current
        if let firstID = prefs.pinnedSpotIDs.first,
           let match = Spot.samples.first(where: { $0.id == firstID }) {
            return match
        }
        return Spot.samples[0]
    }

    private static func computeBestWindow() -> BestWindow? {
        let prefs = UserPreferences.current
        let pinned = Spot.samples.filter { prefs.pinnedSpotIDs.contains($0.id) }
        let candidates = pinned.isEmpty ? Spot.samples : pinned
        return BestWindowCalculator.compute(from: candidates)
    }

    private static func resolveGreetingName() -> String? {
        let trimmed = (UserPreferences.current.name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Root

struct HomeContentView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section(title: "Should I go?") {
                    PrimarySpotCard(
                        spot: viewModel.primarySpot,
                        phase: viewModel.summarizer.phase,
                        greetingName: viewModel.greetingName
                    )
                }

                section(title: "Best window this week") {
                    if let window = viewModel.bestWindow {
                        BestWindowCard(window: window)
                    } else {
                        BestWindowEmptyCard()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 96)
        }
        .task(id: viewModel.primarySpot.id) {
            await viewModel.loadSummary()
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            content()
        }
    }
}

// MARK: - Primary Spot Card

private struct PrimarySpotCard: View {
    let spot: Spot
    let phase: WeatherSummarizeGenerator.Phase
    let greetingName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            verdictRow
            summaryText
            chips
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: spot.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(spot.tint)
                Text(spot.name)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Spacer()
                Text(weekday)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var verdictRow: some View {
        switch phase {
        case .ready(let recommendation):
            HStack(spacing: 10) {
                VerdictPill(verdict: recommendation.verdict)
                Text(recommendation.bestWindow)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
        case .loading:
            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 76, height: 26)
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 96, height: 26)
            }
            .redacted(reason: .placeholder)
        case .idle, .failed:
            EmptyView()
        }
    }

    @ViewBuilder
    private var summaryText: some View {
        switch phase {
        case .ready(let recommendation):
            Text(recommendation.summary)
                .font(.system(size: 15))
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        case .loading:
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.08))
                    .frame(maxWidth: 220)
                    .frame(height: 12)
            }
            .redacted(reason: .placeholder)
        case .idle, .failed:
            EmptyView()
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                WaveHeightChip(
                    height: spot.peakWave?.heightMeters ?? spot.currentWaveHeight,
                    tint: spot.tint,
                    label: "Peak"
                )
                MetricChip(
                    symbol: "metronome",
                    primary: "\(Int(round(spot.peakWave?.periodSeconds ?? 0)))s",
                    secondary: "Period",
                    tint: spot.tint
                )
                WindChip(wind: spot.wind, tint: spot.tint)
                WeatherChip(weather: spot.weather, tint: spot.tint)
                MetricChip(
                    symbol: "thermometer.medium",
                    primary: "\(Int(round(spot.waterTempC)))°",
                    secondary: "Water",
                    tint: spot.tint
                )
            }
            .padding(.vertical, 2)
        }
    }

    private var greeting: String {
        if let name = greetingName { return "Hey \(name)," }
        return "Today's window"
    }

    private var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
}

private struct VerdictPill: View {
    let verdict: SurfVerdict

    var body: some View {
        Text(verdict.rawValue)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(color))
    }

    private var color: Color {
        switch verdict {
        case .go:    return .green
        case .maybe: return .orange
        case .skip:  return .red
        }
    }
}
