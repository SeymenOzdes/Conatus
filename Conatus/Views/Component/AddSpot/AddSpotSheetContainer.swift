//
//  AddSpotSheetContainer.swift
//  Conatus
//

import SwiftUI

struct AddSpotSheetContainer: View {
    @Bindable var presenter: AddSpotPresenter
    var onSave: (UserSpot) -> Void
    var onClose: () -> Void

    var body: some View {
        Group {
            if presenter.isPresented {
                AddSpotSheetView(presenter: presenter, onSave: onSave, onClose: onClose)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: presenter.isPresented)
    }
}
