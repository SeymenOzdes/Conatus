//
//  StartSessionBackdrop.swift
//  Conatus
//
//  Full-screen dim layer that fades in with the Start a Session sheet so the
//  content behind recedes and the sheet's edges read against a calm backdrop.
//

import SwiftUI

struct StartSessionBackdrop: View {
    @Bindable var presenter: StartSessionPresenter
    var onTap: () -> Void

    var body: some View {
        ZStack {
            if presenter.isPresented {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }
                    .transition(.opacity)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Dismiss")
            }
        }
        // When the sheet isn't presented, this view's full-screen host must let
        // taps pass through to the tab bar and underlying tab content.
        .allowsHitTesting(presenter.isPresented)
        .animation(.easeInOut(duration: 0.22), value: presenter.isPresented)
    }
}
