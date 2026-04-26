//
//  SpotDetailSheetContainer.swift
//  Conatus
//
//  Created by Seymen Özdeş on 23.04.2026.
//

import SwiftUI

@Observable
final class SpotDetailPresenter {
    var selectedSpot: Spot?
}

struct SpotDetailSheetContainer: View {
    @Bindable var presenter: SpotDetailPresenter
    var onClose: () -> Void
    var onExpand: () -> Void

    var body: some View {
        Group {
            if let spot = presenter.selectedSpot {
                SpotDetailSheetView(spot: spot, onClose: onClose, onExpand: onExpand)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: presenter.selectedSpot?.id)
    }
}
