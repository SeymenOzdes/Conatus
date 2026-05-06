//
//  OnboardingProgressBar.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct OnboardingProgressBar: View {
    let total: Int
    let current: Int

    private var fillFraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(current + 1) / CGFloat(total)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFF2D8D), Color(hex: 0xFF9500)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * fillFraction)
            }
        }
        .frame(height: 5)
        .animation(.easeInOut(duration: 0.8), value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}
