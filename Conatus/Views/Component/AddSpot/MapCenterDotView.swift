//
//  MapCenterDotView.swift
//  Conatus
//

import SwiftUI

struct MapCenterDotView: View {
    @Bindable var presenter: AddSpotPresenter

    var body: some View {
        ZStack {
            if presenter.isPresented {
                dot
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.32, bounce: 0.2), value: presenter.isPresented)
        .allowsHitTesting(false)
    }

    private var dot: some View {
        Circle()
            .fill(Color.accentColor)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 4, height: 4)
            )
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}
