//
//  SpotDetailView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 26.04.2026.
//

import SwiftUI

struct SpotDetailView: View {
    let spot: Spot
    var onClose: () -> Void
    let summarizer: WeatherSummarizeGenerator

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            content
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                SpotDetailMetricsRow(spot: spot)
                SpotWaveHeroCard(spot: spot)
                SpotDetailSecondaryStatsGrid(spot: spot)
                SpotDetailRecommendationSection(spot: spot, phase: summarizer.phase)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(spot.name)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(.circle)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}

#Preview {
    SpotDetailView(spot: Spot.samples[0], onClose: {}, summarizer: WeatherSummarizeGenerator())
}
