//
//  HeightDisplayScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct HeightDisplayScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingScaffold(
            icon: "water.waves",
            title: "How do you\nmeasure waves?",
            progress: (state.currentStep, state.totalSteps),
            canGoBack: state.canGoBack,
            onBack: { state.back() },
            ctaTitle: "Next",
            ctaEnabled: state.canAdvance,
            onCTA: { state.next() }
        ) {
            VStack(spacing: 12) {
                OnboardingPill(
                    title: "Wave Face Size",
                    subtitle: "What you see from the beach",
                    isSelected: state.heightDisplay == .waveFace
                ) {
                    state.heightDisplay = .waveFace
                }
                OnboardingPill(
                    title: "Swell Height",
                    subtitle: "Raw buoy and model data",
                    isSelected: state.heightDisplay == .swellHeight
                ) {
                    state.heightDisplay = .swellHeight
                }
            }
        }
    }
}
