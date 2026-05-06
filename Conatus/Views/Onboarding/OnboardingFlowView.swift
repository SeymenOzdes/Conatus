//
//  OnboardingFlowView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var state: OnboardingState

    init(onComplete: @escaping () -> Void) {
        _state = State(initialValue: OnboardingState(onComplete: onComplete))
    }

    var body: some View {
        ZStack {
            currentScreen
                .id(state.currentStep)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: state.isGoingBack ? .leading : .trailing)),
                        removal: .opacity
                    )
                )
        }
        .animation(.easeInOut(duration: 0.5), value: state.currentStep)
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch state.currentStep {
        case 0: NameScreen(state: state)
        case 1: PersonaScreen(state: state)
        case 2: PinSpotsScreen(state: state)
        case 3: HeightDisplayScreen(state: state)
        case 4: UnitsScreen(state: state)
        case 5: LocationPermissionScreen(state: state)
        case 6: HealthPermissionScreen(state: state)
        case 7: NotificationsPermissionScreen(state: state)
        case 8: InstantWinScreen(state: state)
        default: EmptyView()
        }
    }
}
