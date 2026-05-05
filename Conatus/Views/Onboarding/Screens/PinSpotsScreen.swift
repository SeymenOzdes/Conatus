//
//  PinSpotsScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct PinSpotsScreen: View {
    @Bindable var state: OnboardingState
    @State private var query: String = ""

    private var filteredSpots: [Spot] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Spot.samples }
        return Spot.samples.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var pinnedSpots: [Spot] {
        Spot.samples.filter { state.pinnedSpotIDs.contains($0.id) }
    }

    var body: some View {
        OnboardingScaffold(
            icon: "mappin.and.ellipse",
            title: "Where do\nyou surf?",
            progress: (state.currentStep, state.totalSteps),
            canGoBack: state.canGoBack,
            onBack: { state.back() },
            ctaTitle: "Continue",
            ctaEnabled: state.canAdvance,
            onCTA: { state.next() }
        ) {
            VStack(spacing: 14) {
                OnboardingSearchField(text: $query)

                if state.pinnedSpotsAtMax {
                    Text("3 of 3 selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                }

                if !pinnedSpots.isEmpty {
                    pinnedChips
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ScrollView {
                    OnboardingSpotSuggestionsView(
                        spots: filteredSpots,
                        pinnedIDs: state.pinnedSpotIDs,
                        isAtMax: state.pinnedSpotsAtMax,
                        onTap: { state.togglePinnedSpot($0.id) }
                    )
                    .animation(.spring(duration: 0.35), value: filteredSpots.map(\.id))
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: .infinity)
            }
            .animation(.spring(duration: 0.3), value: state.pinnedSpotIDs)
        }
    }

    // MARK: - Pinned chips

    private var pinnedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pinnedSpots) { spot in
                    pinnedChip(spot)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func pinnedChip(_ spot: Spot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: spot.symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(spot.name)
                .font(.system(size: 13, weight: .semibold))
            Button {
                state.togglePinnedSpot(spot.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(spot.name)")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(spot.tint.opacity(0.4)))
        .overlay(Capsule().strokeBorder(spot.tint, lineWidth: 1))
    }
}
