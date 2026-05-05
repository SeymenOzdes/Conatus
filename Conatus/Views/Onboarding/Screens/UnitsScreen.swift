//
//  UnitsScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct UnitsScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingScaffold(
            icon: "ruler",
            title: "Pick\nyour units",
            progress: (state.currentStep, state.totalSteps),
            canGoBack: state.canGoBack,
            onBack: { state.back() },
            ctaTitle: "Next",
            ctaEnabled: state.canAdvance,
            onCTA: { state.next() }
        ) {
            HStack(spacing: 12) {
                OnboardingPill(
                    title: "Imperial",
                    subtitle: "ft, mph, °F",
                    isSelected: state.units == .imperial
                ) {
                    state.units = .imperial
                }
                OnboardingPill(
                    title: "Metric",
                    subtitle: "m, km/h, °C",
                    isSelected: state.units == .metric
                ) {
                    state.units = .metric
                }
            }
        }
    }
}
