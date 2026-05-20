//
//  StartSessionSummaryStep.swift
//  Conatus
//

import SwiftUI

struct StartSessionSummaryStep: View {
    @Bindable var presenter: StartSessionPresenter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let picked = presenter.pickedSpot {
                    row(icon: "mappin.circle.fill", label: "Spot", value: picked.name)
                }
                row(icon: "clock", label: "Duration", value: durationLabel)
                row(icon: "water.waves", label: "Waves", value: "\(presenter.waveCount)")
                row(icon: "surfboard.fill", label: "Board", value: presenter.boardType.displayName, fallbackIcon: "figure.surfing")
                row(icon: "arrow.up.and.down", label: "Wave size", value: presenter.waveSize.displayName)
                row(icon: "person.3.fill", label: "Crowd", value: presenter.crowdLevel.displayName)
                row(icon: "star.fill", label: "Vibe", value: String(repeating: "★", count: presenter.rating) + String(repeating: "☆", count: 5 - presenter.rating))
                if !presenter.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notesRow
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 420)
        .scrollIndicators(.hidden)
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

    private func row(icon: String, label: String, value: String, fallbackIcon: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: resolvedIcon(icon, fallback: fallbackIcon))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.65))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    private var notesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .frame(width: 22)
                Text("Notes")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.65))
                Spacer(minLength: 0)
            }
            Text(presenter.notes)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    private func resolvedIcon(_ name: String, fallback: String?) -> String {
        // surfboard.fill isn't in older SF Symbols sets; let fallback resolve at runtime.
        if name == "surfboard.fill" { return fallback ?? "figure.surfing" }
        return name
    }
}
