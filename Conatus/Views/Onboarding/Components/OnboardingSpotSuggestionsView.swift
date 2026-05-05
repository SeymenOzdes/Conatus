//
//  OnboardingSpotSuggestionsView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI
import CoreLocation

struct OnboardingSpotSuggestionsView: View {
    let spots: [Spot]
    let pinnedIDs: Set<UUID>
    let isAtMax: Bool
    let onTap: (Spot) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                let isPinned = pinnedIDs.contains(spot.id)
                let disabled = isAtMax && !isPinned

                row(spot: spot, isPinned: isPinned, disabled: disabled)
                    .transition(.asymmetric(
                        insertion: .opacity
                            .combined(with: .move(edge: .top))
                            .animation(.easeOut(duration: 0.25).delay(Double(index) * 0.04)),
                        removal: .opacity.animation(.easeOut(duration: 0.15))
                    ))
            }
        }
    }

    @ViewBuilder
    private func row(spot: Spot, isPinned: Bool, disabled: Bool) -> some View {
        Button {
            onTap(spot)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: spot.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(spot.tint)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.16)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(coordinateLabel(spot))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: isPinned ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isPinned ? .white : .white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isPinned ? 0.22 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .animation(.spring(duration: 0.2), value: isPinned)
        .animation(.spring(duration: 0.2), value: disabled)
    }

    private func coordinateLabel(_ spot: Spot) -> String {
        String(
            format: "%.2f°, %.2f°",
            spot.coordinate.latitude,
            spot.coordinate.longitude
        )
    }
}
