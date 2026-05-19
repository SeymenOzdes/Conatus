//
//  AddSpotButton.swift
//  Conatus
//

import SwiftUI

struct AddSpotButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Add Spot")
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.cyan.opacity(0.5), .blue.opacity(0.4)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        AddSpotButton(action: {})
    }
}
