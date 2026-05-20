//
//  StartSessionSheetView.swift
//  Conatus
//

import SwiftUI

struct StartSessionSheetView: View {
    @Bindable var presenter: StartSessionPresenter
    let pinnedSpots: [Spot]
    var onSave: (UserSession) -> Void
    var onClose: () -> Void

    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 28,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 28,
            style: .continuous
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            stepBody
            footer
        }
        .padding(18)
        .background(
            sheetShape
                .fill(Color(hex: 0x1F3CFF))
                .ignoresSafeArea(.container, edges: .bottom)
        )
        .overlay(
            sheetShape
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                .ignoresSafeArea(.container, edges: .bottom)
        )
        .shadow(color: .black.opacity(0.38), radius: 30, x: 0, y: -6)
        .animation(.spring(duration: 0.32, bounce: 0.18), value: presenter.step)
        .animation(.spring(duration: 0.28, bounce: 0.15), value: presenter.pickedSpot)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            VStack(spacing: 8) {
                Text(title(for: presenter.step))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                StepIndicator(step: presenter.step)
            }
            .frame(maxWidth: .infinity)

            HStack {
                if presenter.step != .location {
                    Button {
                        presenter.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                    .transition(.opacity)
                }

                Spacer(minLength: 0)

                Button {
                    onClose()
                } label: {
                    Text("Close")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
    }

    // MARK: - Step body

    @ViewBuilder
    private var stepBody: some View {
        switch presenter.step {
        case .location:
            StartSessionLocationStep(presenter: presenter, pinnedSpots: pinnedSpots)
        case .details:
            StartSessionDetailsStep(presenter: presenter)
        case .summary:
            StartSessionSummaryStep(presenter: presenter)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        OnboardingPrimaryButton(
            title: presenter.step == .summary ? "Save session" : "Continue",
            isEnabled: presenter.canContinue
        ) {
            if presenter.step == .summary {
                guard let session = presenter.buildSession() else { return }
                onSave(session)
            } else {
                presenter.goNext()
            }
        }
        .padding(.horizontal, -24) // cancel OnboardingPrimaryButton's internal 24pt inset
        .padding(.top, 2)
    }

    private func title(for step: StartSessionPresenter.Step) -> String {
        switch step {
        case .location: return "Pick a location"
        case .details:  return "Session details"
        case .summary:  return "Review & save"
        }
    }
}

private struct StepIndicator: View {
    let step: StartSessionPresenter.Step

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StartSessionPresenter.Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.white : Color.white.opacity(0.30))
                    .frame(width: s == step ? 18 : 8, height: 4)
            }
        }
        .animation(.spring(duration: 0.28, bounce: 0.2), value: step)
    }
}
