//
//  OnboardingProgressDots.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct OnboardingProgressDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.white : Color.white.opacity(0.3))
                    .frame(
                        width: index == current ? 8 : 6,
                        height: index == current ? 8 : 6
                    )
                    .animation(.spring(duration: 0.3), value: current)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}
