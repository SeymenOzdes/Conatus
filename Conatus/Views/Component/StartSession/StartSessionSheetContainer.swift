//
//  StartSessionSheetContainer.swift
//  Conatus
//

import SwiftUI

struct StartSessionSheetContainer: View {
    @Bindable var presenter: StartSessionPresenter
    var pinnedSpots: () -> [Spot]
    var onSave: (UserSession) -> Void
    var onClose: () -> Void

    var body: some View {
        Group {
            if presenter.isPresented {
                StartSessionSheetView(
                    presenter: presenter,
                    pinnedSpots: pinnedSpots(),
                    onSave: onSave,
                    onClose: onClose
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: presenter.isPresented)
    }
}
