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
    let summarizer = WeatherSummarizeGenerator()
    private let conditionsService = SpotConditionsService()
    private var conditionsTask: Task<Void, Never>?

    func select(_ spot: Spot?) {
        selectedSpot = spot
        guard let spot else {
            conditionsTask?.cancel()
            conditionsTask = nil
            summarizer.cancel()
            return
        }
        guard !spot.isPlaceholder else {
            summarizer.cancel()
            return
        }
        Task { await summarizer.generate(for: spot) }
    }

    func select(_ result: SpotResult) {
        conditionsTask?.cancel()
        select(Spot.placeholder(from: result))

        conditionsTask = Task { [weak self] in
            guard let self else { return }
            do {
                let dto = try await self.conditionsService.fetchConditions(spotId: result.spotId)
                if Task.isCancelled { return }
                if let spot = dto.makeSpot(from: result) {
                    self.select(spot)
                }
            } catch is CancellationError {
                // ignored — superseded by a newer selection
            } catch {
                // network / inland fallback: leave placeholder in place
            }
        }
    }
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
