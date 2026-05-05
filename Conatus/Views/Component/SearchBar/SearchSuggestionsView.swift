//
//  SearchSuggestionsView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct SearchSuggestionsView: View {
    let spots: [Spot]
    var onSelect: (Spot) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                Button {
                    onSelect(spot)
                } label: {
                    row(for: spot)
                }
                .buttonStyle(SuggestionRowButtonStyle())
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .animation(.easeOut(duration: 0.22).delay(Double(index) * 0.035)),
                        removal: .opacity.animation(.easeOut(duration: 0.12))
                    )
                )

                if index < spots.count - 1 {
                    Divider()
                        .opacity(0.22)
                }
            }
        }
        .padding(.vertical, 4)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(for spot: Spot) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(spot.tint.opacity(0.18))
                    .frame(width: 24, height: 24)
                Image(systemName: spot.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(spot.tint)
            }

            Text(spot.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

private struct SuggestionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.cyan.opacity(0.5), .blue.opacity(0.4)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        SearchSuggestionsView(spots: Spot.samples) { _ in }
            .padding(.horizontal, 16)
    }
}
