//
//  PersonaScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct PersonaScreen: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingScaffold(
            icon: "figure.surfing",
            title: "What kind of\nsurfer are you?",
            progress: (state.currentStep, state.totalSteps),
            canGoBack: state.canGoBack,
            onBack: { state.back() },
            ctaTitle: "Next",
            ctaEnabled: state.canAdvance,
            onCTA: { state.next() }
        ) {
            VStack(spacing: 12) {
                ForEach(UserPreferences.Persona.allCases, id: \.self) { persona in
                    OnboardingPill(
                        title: title(for: persona),
                        subtitle: subtitle(for: persona),
                        isSelected: state.persona == persona
                    ) {
                        state.persona = persona
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func title(for persona: UserPreferences.Persona) -> String {
        switch persona {
        case .beginner:     return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced:     return "Advanced"
        }
    }

    private func subtitle(for persona: UserPreferences.Persona) -> String {
        switch persona {
        case .beginner:     return "Still learning to read waves — keep it simple"
        case .intermediate: return "I know my spots, want reliable forecasts"
        case .advanced:     return "Full model data, raw buoys, custom thresholds"
        }
    }
}
