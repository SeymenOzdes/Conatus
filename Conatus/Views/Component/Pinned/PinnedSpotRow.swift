//
//  PinnedSpotRow.swift
//  Conatus
//

import SwiftUI

struct PinnedSpotRow: View {
    let rank: Int
    let spot: Spot
    let units: UserPreferences.Units

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(String(format: "%02d", rank))
                .font(.system(size: 12))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(spot.name)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    ConditionTagStack(tags: spot.conditionTags)
                }
                if let subtitle = spot.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(spot.displayedWaveRange(units: units))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                SurfStatusPill(status: spot.surfStatus)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 4)
    }
}
