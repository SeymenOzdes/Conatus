//
//  OnboardingScaffold.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI
import Beam

struct OnboardingScaffold<Content: View>: View {
    let icon: String
    let title: String
    let progress: (current: Int, total: Int)
    let canGoBack: Bool
    let onBack: (() -> Void)?
    let ctaTitle: String
    let ctaEnabled: Bool
    let onCTA: () -> Void
    var secondaryCTA: (title: String, action: () -> Void)? = nil
    @ViewBuilder let content: Content

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            heroSection
            content
                .padding(.horizontal, 24)
            Spacer(minLength: 16)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onboardingBackground()
        .preferredColorScheme(.dark)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            backButton
            Spacer()
            OnboardingProgressDots(total: progress.total, current: progress.current)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var backButton: some View {
        if canGoBack, let onBack {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
        } else {
            Color.clear.frame(width: 36, height: 36)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 28) {
            Image(systemName: icon)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.white, Color(hex: 0x1F3CFF))
                .symbolRenderingMode(.palette)
                .frame(height: 120)
                .padding(.top, 24)

            Text(title)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            OnboardingPrimaryButton(title: ctaTitle, isEnabled: ctaEnabled, action: onCTA)
            if let secondary = secondaryCTA {
                Button(secondary.title, action: secondary.action)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.bottom, 16)
    }
}
