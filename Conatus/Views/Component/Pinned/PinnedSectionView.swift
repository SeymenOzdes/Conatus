//
//  PinnedSectionView.swift
//  Conatus
//

import SwiftUI

struct PinnedSectionView: View {
    let spots: [Spot]
    let units: UserPreferences.Units

    var body: some View {
        if spots.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("PINNED · \(spots.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                VStack(spacing: 0) {
                    Divider().opacity(0.22)
                    ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                        PinnedSpotRow(rank: index + 1, spot: spot, units: units)
                        Divider().opacity(0.22)
                    }
                }
            }
        }
    }
}
