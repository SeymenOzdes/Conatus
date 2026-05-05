//
//  HealthPermissionScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct HealthPermissionScreen: View {
    @Bindable var state: OnboardingState
    @State private var coordinator = PermissionsCoordinator()
    @State private var inFlight = false

    var body: some View {
        OnboardingScaffold(
            icon: "heart.fill",
            title: "Track your\nsessions",
            progress: (state.currentStep, state.totalSteps),
            canGoBack: state.canGoBack,
            onBack: { state.back() },
            ctaTitle: "Allow Health Access",
            ctaEnabled: !inFlight,
            onCTA: { request() },
            secondaryCTA: ("Skip for now", { skip() })
        ) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingExplainerRow(
                    icon: "applewatch",
                    title: "Watch sessions",
                    detail: "Auto-log paddle time and heart rate from Apple Watch."
                )
                OnboardingExplainerRow(
                    icon: "flame.fill",
                    title: "Paddle fitness",
                    detail: "See the calories you burn over a session."
                )
                OnboardingExplainerRow(
                    icon: "lock.shield.fill",
                    title: "You're in control",
                    detail: "Pick exactly which data Conatus can read in Health."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func request() {
        inFlight = true
        Task {
            let result = await coordinator.requestHealth()
            state.permissions.health = result
            inFlight = false
            state.next()
        }
    }

    private func skip() {
        state.permissions.health = .skipped
        state.next()
    }
}
