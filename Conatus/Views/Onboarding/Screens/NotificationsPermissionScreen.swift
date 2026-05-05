//
//  NotificationsPermissionScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct NotificationsPermissionScreen: View {
    @Bindable var state: OnboardingState
    @State private var coordinator = PermissionsCoordinator()
    @State private var inFlight = false

    var body: some View {
        OnboardingScaffold(
            icon: "bell.badge.fill",
            title: "Catch the\nbest windows",
            progress: (state.currentStep, state.totalSteps),
            canGoBack: state.canGoBack,
            onBack: { state.back() },
            ctaTitle: "Enable Notifications",
            ctaEnabled: !inFlight,
            onCTA: { request() },
            secondaryCTA: ("Skip for now", { skip() })
        ) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingExplainerRow(
                    icon: "wave.3.right",
                    title: "Epic-condition alerts",
                    detail: "Ping when your custom threshold is hit at a pinned spot."
                )
                OnboardingExplainerRow(
                    icon: "calendar",
                    title: "Morning forecast brief",
                    detail: "A short daily summary of the day's best window."
                )
                OnboardingExplainerRow(
                    icon: "slider.horizontal.3",
                    title: "Tweak anytime",
                    detail: "Adjust frequency and quiet hours in Settings."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func request() {
        inFlight = true
        Task {
            let result = await coordinator.requestNotifications()
            state.permissions.notifications = result
            inFlight = false
            state.next()
        }
    }

    private func skip() {
        state.permissions.notifications = .skipped
        state.next()
    }
}
