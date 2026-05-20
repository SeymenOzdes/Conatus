//
//  StartSessionSummaryStep.swift
//  Conatus
//

import SwiftUI

struct StartSessionSummaryStep: View {
    @Bindable var presenter: StartSessionPresenter

    var body: some View {
        ScrollView {
            card
                .padding(.vertical, 2)
        }
        .frame(maxHeight: 420)
        .scrollIndicators(.hidden)
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 0.5)
            statsRow
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 3) {
                Text(presenter.pickedSpot?.name ?? "Session")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 0) {
            stat(icon: "water.waves", value: "\(presenter.waveCount)", label: "Waves")
            statDivider
            stat(icon: presenter.waveSize.iconName, value: presenter.waveSize.displayName, label: "Wave size")
            statDivider
            stat(icon: "star.fill", value: "\(presenter.rating)/5", label: "Vibe")
        }
    }

    // MARK: - Helpers

    private var subtitle: String {
        "\(presenter.boardType.displayName) · \(durationLabel)"
    }

    private var durationLabel: String {
        let total = Int(max(0, presenter.endedAt.timeIntervalSince(presenter.startedAt)).rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(width: 0.5, height: 40)
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}
