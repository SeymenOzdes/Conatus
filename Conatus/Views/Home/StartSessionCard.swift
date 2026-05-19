//
//  StartSessionCard.swift
//  Conatus
//

import SwiftUI

struct StartSessionCard: View {

    private let accent = Color(red: 0.0, green: 0.74, blue: 0.74)

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("READY WHEN YOU ARE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Text("Start a session")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            ZStack {
                Circle().fill(accent)
                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}
