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
