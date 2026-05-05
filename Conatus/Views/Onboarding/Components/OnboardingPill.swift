//
//  OnboardingPill.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct OnboardingPill: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .opacity(0.75)
                }
            }
            .foregroundStyle(isSelected ? Color(hex: 0x1F3CFF) : .white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}
