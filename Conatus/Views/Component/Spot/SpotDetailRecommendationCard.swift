//
//  SpotDetailRecommendationCard.swift
//  Conatus
//
//  Created by Codex on 31.05.2026.
//

import SwiftUI

struct SpotDetailRecommendationSection: View {
    let spot: Spot
    let phase: WeatherSummarizeGenerator.Phase

    var body: some View {
        content
            .animation(.easeInOut(duration: 0.25), value: phase)
    }

    @ViewBuilder
    private var content: some View {
        if spot.isPlaceholder || spot.hourlyWaves.isEmpty {
            recommendationCard(
                title: "AI surf call",
                subtitle: "Conditions unavailable",
                stateIcon: "exclamationmark.triangle",
                recommendation: SurfRecommendation.unavailable,
                tone: .secondary,
                showsReasons: false
            )
        } else {
            switch phase {
            case .idle, .loading:
                loadingRecommendationCard
            case .ready(let recommendation):
                recommendationCard(
                    title: "AI surf call",
                    subtitle: "Next 12 hours",
                    stateIcon: "sparkles",
                    recommendation: recommendation,
                    tone: verdictColor(recommendation.verdict)
                )
                .transition(.opacity)
            case .unavailable(let recommendation):
                recommendationCard(
                    title: "AI surf call",
                    subtitle: "Local fallback",
                    stateIcon: "wifi.slash",
                    recommendation: recommendation,
                    tone: .secondary
                )
                .transition(.opacity)
            case .failed(let recommendation):
                recommendationCard(
                    title: "AI surf call",
                    subtitle: "AI fallback",
                    stateIcon: "exclamationmark.triangle",
                    recommendation: recommendation,
                    tone: .orange
                )
                .transition(.opacity)
            }
        }
    }

    private var loadingRecommendationCard: some View {
        recommendationCard(
            title: "AI surf call",
            subtitle: "Analyzing forecast",
            stateIcon: "sparkles",
            recommendation: SurfRecommendation.loading,
            tone: spot.tint
        )
        .redacted(reason: .placeholder)
        .accessibilityLabel("AI surf call analyzing forecast")
    }

    private func recommendationCard(
        title: String,
        subtitle: String,
        stateIcon: String,
        recommendation: SurfRecommendation,
        tone: Color,
        showsReasons: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: stateIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular, in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                verdictPill(recommendation.verdict, color: verdictColor(recommendation.verdict))
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    recommendationMetric(
                        symbol: "clock",
                        label: "Best window",
                        value: recommendation.bestWindow
                    )
                    Divider()
                    recommendationMetric(
                        symbol: "gauge.with.dots.needle.33percent",
                        label: "Confidence",
                        value: recommendation.confidence.rawValue
                    )
                }
                .fixedSize(horizontal: false, vertical: true)

                Text(recommendation.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsReasons, !recommendation.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(recommendation.reasons.prefix(3).enumerated()), id: \.offset) { _, reason in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tone)
                                .padding(.top, 2)
                            Text(reason)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "figure.surfing")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tone)
                Text(recommendation.action)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tone.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: recommendation, subtitle: subtitle))
    }

    private func verdictPill(_ verdict: SurfVerdict, color: Color) -> some View {
        Text(verdict.rawValue)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func recommendationMetric(symbol: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(label, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accessibilityLabel(for recommendation: SurfRecommendation, subtitle: String) -> String {
        let reasons = recommendation.reasons.prefix(3).joined(separator: ". ")
        return [
            "AI surf call",
            subtitle,
            "Verdict \(recommendation.verdict.rawValue)",
            "Best window \(recommendation.bestWindow)",
            "Confidence \(recommendation.confidence.rawValue)",
            recommendation.summary,
            reasons,
            recommendation.action
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ". ")
    }

    private func verdictColor(_ verdict: SurfVerdict) -> Color {
        switch verdict {
        case .go:    return .green
        case .maybe: return .orange
        case .skip:  return .red
        }
    }
}

