//
//  NameScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 06.05.2026.
//

import SwiftUI

struct NameScreen: View {
    @Bindable var state: OnboardingState
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Text("What's your name?")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)

            Spacer(minLength: 24)

            TextField(
                "",
                text: $state.name,
                prompt: Text("Full Name")
                    .foregroundStyle(Color.white.opacity(0.35))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
            )
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(true)
            .submitLabel(.continue)
            .focused($isFocused)
            .onSubmit {
                if state.canAdvance { state.next() }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 24)

            OnboardingPrimaryButton(
                title: "Continue",
                isEnabled: state.canAdvance,
                action: { state.next() }
            )
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onboardingBackground()
        .preferredColorScheme(.dark)
        .onAppear { isFocused = true }
    }

    // MARK: - Top bar

    private var topBar: some View {
        GeometryReader { proxy in
            let barWidth = (proxy.size.width - 32) * 0.75
            HStack(spacing: 0) {
                Color.clear.frame(width: 36, height: 36)
                Spacer(minLength: 0)
                OnboardingProgressBar(total: state.totalSteps, current: state.currentStep)
                    .frame(width: barWidth)
                Spacer(minLength: 0)
                Color.clear.frame(width: 36, height: 36)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .frame(height: 56)
    }
}
