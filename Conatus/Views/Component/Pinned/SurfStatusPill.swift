//
//  SurfStatusPill.swift
//  Conatus
//

import SwiftUI

struct SurfStatusPill: View {
    let status: Spot.SurfStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
    }
}
