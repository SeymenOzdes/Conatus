//
//  FreeTrialScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 10.05.2026.
//

import SwiftUI

struct FreeTrialScreen: View {
    @Bindable var state: OnboardingState
    @Environment(\.openURL) private var openURL
    @State private var showRestoreAlert = false

    private let placeholderPrice = "$4.99"
    private let placeholderPeriod = "month"

    private let trialLength = 30
    private let reminderLeadDays = 2

    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://conatus.app/privacy")!

    private let accent = Color(hex: 0x1F3CFF)

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headline
                    timeline
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onboardingBackground()
        .preferredColorScheme(.dark)
        .alert("No purchases to restore", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't find an active Conatus subscription on this Apple ID.")
        }
    }

    // MARK: - Header

    private var header: some View {
        GeometryReader { proxy in
            let barWidth = (proxy.size.width - 32) * 0.75
            HStack(spacing: 0) {
                Button(action: { state.back() }) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
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

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try Conatus Pro free for \(trialLength) days.")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Then \(placeholderPrice)/\(placeholderPeriod). Cancel anytime.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrialTimelineRow(
                title: "Today",
                detail: "Unlock Pro features: AI surf verdicts, multi-spot best-window, and session logging.",
                accent: accent,
                style: .leading
            )

            TrialTimelineRow(
                title: "In \(trialLength - reminderLeadDays) days",
                detail: "We'll remind you \(reminderLeadDays) days before your trial ends.",
                accent: accent,
                style: .middle
            )

            TrialTimelineRow(
                title: "In \(trialLength) days",
                detail: "Your subscription begins. Cancel anytime in Settings at least 24 hours before.",
                accent: accent,
                style: .trailing
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            OnboardingPrimaryButton(
                title: "Start Free Trial",
                isEnabled: true,
                action: { state.complete() }
            )

            HStack(spacing: 24) {
                Button("Restore Purchases") {
                    // TODO: wire to AppStore.sync() once StoreKit2 is integrated.
                    showRestoreAlert = true
                }
                Button("Maybe later") {
                    state.complete()
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))

            legalFooter
        }
        .padding(.bottom, 16)
    }

    private var legalFooter: some View {
        HStack(spacing: 4) {
            Button("Terms of Use") { openURL(termsURL) }
            Text("·")
            Button("Privacy Policy") { openURL(privacyURL) }
        }
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.55))
        .padding(.top, 4)
    }
}

// MARK: - Timeline row

private struct TrialTimelineRow: View {
    enum Style { case leading, middle, trailing }

    let title: String
    let detail: String
    let accent: Color
    let style: Style

    private let dotSize: CGFloat = 9.3
    private let railWidth: CGFloat = 7
    private let railColumnWidth: CGFloat = 14

    var body: some View {
        HStack(alignment: .top, spacing: 37) {
            railColumn
                .frame(width: railColumnWidth)

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 19.5, weight: .semibold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, style == .trailing ? 0 : 28)
        }
        .accessibilityElement(children: .combine)
    }

    private var railColumn: some View {
        VStack(spacing: 9) {
            Circle()
                .fill(accent)
                .frame(width: dotSize, height: dotSize)

            switch style {
            case .leading, .middle:
                Rectangle()
                    .fill(accent)
                    .frame(width: railWidth)
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 9)
            case .trailing:
                Image(systemName: "arrow.down")
                    .font(.system(size: 49, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }
}
