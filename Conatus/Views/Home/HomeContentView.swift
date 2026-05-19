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
    private(set) var pinnedSpots: [Spot]
    private(set) var units: UserPreferences.Units

    init() {
        self.greetingName = Self.resolveGreetingName()
        self.pinnedSpots = Self.resolvePinnedSpots()
        self.units = UserPreferences.current.units ?? .imperial
    }

    func refresh() {
        greetingName = Self.resolveGreetingName()
        pinnedSpots = Self.resolvePinnedSpots()
        units = UserPreferences.current.units ?? .imperial
    }

    private static func resolveGreetingName() -> String? {
        let trimmed = (UserPreferences.current.name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func resolvePinnedSpots() -> [Spot] {
        let prefs = UserPreferences.current
        return prefs.pinnedSpotIDs.compactMap { id in
            Spot.samples.first(where: { $0.id == id })
        }
    }
}

// MARK: - Root

struct HomeContentView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GreetingHeaderView(name: viewModel.greetingName)
                SessionStatsDialView()
                StartSessionCard()

                if !viewModel.pinnedSpots.isEmpty {
                    PinnedSectionView(
                        spots: viewModel.pinnedSpots,
                        units: viewModel.units
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 96)
        }
    }
}
