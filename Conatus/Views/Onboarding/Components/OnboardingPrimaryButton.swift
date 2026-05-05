//
//  OnboardingPrimaryButton.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI
import Beam

struct OnboardingPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(isEnabled ? Color(hex: 0x1F3CFF) : Color.white.opacity(0.6))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    Capsule()
                        .fill(isEnabled ? Color.white : Color.white.opacity(0.18))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}
