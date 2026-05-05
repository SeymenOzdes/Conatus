//
//  LocationPermissionScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct LocationPermissionScreen: View {
    @Bindable var state: OnboardingState
    @State private var coordinator = PermissionsCoordinator()
    @State private var inFlight = false

    var body: some View {
        OnboardingScaffold(
            icon: "location.fill",
            title: "Find spots\nnear you",
            progress: (state.currentStep, state.totalSteps),
            canGoBack: state.canGoBack,
            onBack: { state.back() },
            ctaTitle: "Allow Location",
            ctaEnabled: !inFlight,
            onCTA: { request() },
            secondaryCTA: ("Skip for now", { skip() })
        ) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingExplainerRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Nearest buoy data",
                    detail: "We'll match the closest forecast model to your spot."
                )
                OnboardingExplainerRow(
                    icon: "wind",
                    title: "Local wind & weather",
                    detail: "Live conditions tailored to where you actually surf."
                )
                OnboardingExplainerRow(
                    icon: "lock.shield.fill",
                    title: "Stays on your device",
                    detail: "Your location never leaves your phone."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func request() {
        inFlight = true
        Task {
            let result = await coordinator.requestLocation()
            state.permissions.location = result
            inFlight = false
            state.next()
        }
    }

    private func skip() {
        state.permissions.location = .skipped
        state.next()
    }
}
