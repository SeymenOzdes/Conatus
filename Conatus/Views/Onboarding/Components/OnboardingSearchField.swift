//
//  OnboardingSearchField.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct OnboardingSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search beach, city, region…"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundStyle(Color.white.opacity(0.6))
            )
            .foregroundStyle(.white)
            .tint(.white)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
