//
//  SessionSelectionList.swift
//  Conatus
//

import SwiftUI

/// Vertical radio-selection list used for single-select session attributes
/// (board type, wave size, crowd). Adopts the Figma "Set Status" row pattern on
/// the blue sheet: leading icon + title + trailing radio, selected row tinted brighter.
struct SessionSelectionList<Option: Hashable>: View {
    let label: String
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let icon: (Option) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.65))
                .tracking(0.6)

            VStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    SessionSelectionRow(
                        title: title(option),
                        icon: icon(option),
                        isSelected: option == selection
                    ) {
                        selection = option
                    }
                }
            }
        }
    }
}

private struct SessionSelectionRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                RadioIndicator(isSelected: isSelected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.18 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.30 : 0.14), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct RadioIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(isSelected ? 1 : 0.4), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(.white)
                    .frame(width: 11, height: 11)
            }
        }
    }
}
