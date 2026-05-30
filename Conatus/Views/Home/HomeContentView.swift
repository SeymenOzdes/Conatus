//
//  HomeContentView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 06.05.2026.
//

import SwiftUI

@Observable
@MainActor
final class HomeViewModel {
    private(set) var greetingName: String?
    private(set) var favoriteSpots: [Spot]
    private(set) var units: UserPreferences.Units

    init() {
        self.greetingName = Self.resolveGreetingName()
        self.favoriteSpots = Self.resolveFavoriteSpots()
        self.units = UserPreferences.current.units ?? .imperial
    }

    func refresh() {
        greetingName = Self.resolveGreetingName()
        favoriteSpots = Self.resolveFavoriteSpots()
        units = UserPreferences.current.units ?? .imperial
    }

    private static func resolveGreetingName() -> String? {
        let trimmed = (UserPreferences.current.name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func resolveFavoriteSpots() -> [Spot] {
        let prefs = UserPreferences.current
        let pinned = prefs.pinnedSpotIDs.compactMap { id in
            Spot.samples.first(where: { $0.id == id })
        }
        return pinned.isEmpty ? Array(Spot.samples.prefix(3)) : pinned
    }
}

// MARK: - Root

struct HomeContentView: View {
    @Bindable var viewModel: HomeViewModel
    @Bindable var startSessionPresenter: StartSessionPresenter
    @Bindable var toastController: HomeToastController
    var onSpotSelected: (Spot) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GreetingHeaderView(name: viewModel.greetingName)
                SessionStatsDialView()
                StartSessionCard {
                    startSessionPresenter.present()
                }

                FavoriteSpotCardsSection(
                    spots: viewModel.favoriteSpots,
                    units: viewModel.units,
                    onSelect: onSpotSelected
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 96)
        }
        .overlay(alignment: .top) {
            if toastController.visible {
                SessionSavedToast(message: toastController.message)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: toastController.visible)
    }
}
