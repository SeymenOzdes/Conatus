//
//  InstantWinScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import CoreLocation
import SwiftUI

struct InstantWinScreen: View {
    @Bindable var state: OnboardingState
    @State private var presenter = InstantWinPresenter()

    var body: some View {
        OnboardingScaffold(
            icon: "sparkles",
            title: "Your best window\nthis week",
            progress: (state.currentStep, state.totalSteps),
            canGoBack: true,
            onBack: { state.back() },
            ctaTitle: ctaTitle,
            ctaEnabled: true,
            onCTA: { state.next() },
            secondaryCTA: ("Skip — go to dashboard", { state.next() })
        ) {
            content
        }
        .task(id: state.pinnedSpotIDs) {
            await presenter.load(for: state.pinnedSpotIDs)
            if case let .loaded(window) = presenter.phase {
                state.bestWindow = window
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch presenter.phase {
        case .idle, .loading:
            BestWindowLoadingCard()
        case let .loaded(window):
            BestWindowCard(window: window)
        case .unavailable, .failed:
            BestWindowEmptyCard()
        }
    }

    private var ctaTitle: String {
        if case .loaded = presenter.phase {
            return "Set an Alert for This Window"
        }
        return "Go to dashboard"
    }
}

@MainActor
@Observable
private final class InstantWinPresenter {
    enum Phase {
        case idle
        case loading
        case loaded(BestWindow)
        case unavailable
        case failed
    }

    var phase: Phase = .idle

    private let searchService: SearchService
    private let conditionsService: SpotConditionsService
    private var lastLoadedPinnedIDs: Set<UUID>?

    init() {
        searchService = SearchService()
        conditionsService = SpotConditionsService()
    }

    func load(for pinnedIDs: Set<UUID>) async {
        guard lastLoadedPinnedIDs != pinnedIDs else { return }
        lastLoadedPinnedIDs = pinnedIDs

        let pinnedSpots = Spot.samples.filter { pinnedIDs.contains($0.id) }
        guard !pinnedSpots.isEmpty else {
            phase = .unavailable
            return
        }

        phase = .loading

        do {
            phase = try await bestWindow(from: pinnedSpots).map(Phase.loaded) ?? .unavailable
        } catch is CancellationError {
            lastLoadedPinnedIDs = nil
        } catch {
            phase = .failed
        }
    }

    private func bestWindow(from spots: [Spot]) async throws -> BestWindow? {
        try await withThrowingTaskGroup(of: Candidate?.self) { group in
            for spot in spots {
                group.addTask { [searchService, conditionsService] in
                    do {
                        guard let result = try await Self.resolveBackendSpot(
                            for: spot,
                            searchService: searchService
                        ) else {
                            return nil
                        }

                        let dto = try await conditionsService.fetchConditions(spotId: result.spotId)
                        guard dto.conditions != nil else { return nil }
                        return Self.bestCandidate(from: dto, localSpot: spot, result: result)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        return nil
                    }
                }
            }

            var best: Candidate?
            for try await candidate in group {
                guard let candidate else { continue }
                if candidate.score > (best?.score ?? Int.min) {
                    best = candidate
                }
            }
            return best?.window
        }
    }

    nonisolated private static func resolveBackendSpot(
        for spot: Spot,
        searchService: SearchService
    ) async throws -> SpotResult? {
        let nearby = try? await searchService.searchNearby(
            lat: spot.coordinate.latitude,
            lng: spot.coordinate.longitude,
            radiusMeters: 30_000,
            limit: 1
        )
        if let result = nearby?.spots.first {
            return result
        }

        let named = try await searchService.search(query: spot.name, limit: 1)
        return named.spots.first
    }

    nonisolated private static func bestCandidate(
        from dto: SpotConditionsDTO,
        localSpot: Spot,
        result: SpotResult
    ) -> Candidate? {
        dto.bestWindows
            .compactMap { window -> Candidate? in
                guard let start = parseDate(window.startTimestamp),
                      let end = parseDate(window.endTimestamp),
                      let metrics = metrics(for: window, in: dto.forecastSlots) else {
                    return nil
                }

                let bestWindow = BestWindow(
                    spotID: localSpot.id,
                    spotName: result.name,
                    weekday: weekdayLabel(for: start),
                    startHour: start,
                    endHour: end,
                    waveHeightMeters: metrics.waveHeightMeters,
                    periodSeconds: metrics.periodSeconds,
                    windSpeedKmh: metrics.windSpeedKmh,
                    summaryText: window.summary
                )
                return Candidate(window: bestWindow, score: window.score)
            }
            .max(by: { $0.score < $1.score })
    }

    nonisolated private static func metrics(
        for window: SpotConditionsDTO.BestWindow,
        in slots: [SpotConditionsDTO.ForecastSlot]
    ) -> WindowMetrics? {
        guard let slot = slots.first(where: {
            $0.startTimestamp == window.startTimestamp && $0.endTimestamp == window.endTimestamp
        }) ?? slots.first(where: {
            guard let slotStart = parseDate($0.startTimestamp),
                  let windowStart = parseDate(window.startTimestamp) else {
                return false
            }
            return abs(slotStart.timeIntervalSince(windowStart)) < 60
        }) else {
            return nil
        }

        guard let waveHeight = slot.waveHeightM,
              let period = slot.wavePeriodS,
              let wind = slot.windSpeedKmh else {
            return nil
        }

        return WindowMetrics(
            waveHeightMeters: waveHeight,
            periodSeconds: period,
            windSpeedKmh: wind
        )
    }

    nonisolated private static func parseDate(_ string: String) -> Date? {
        let internetFormatter = ISO8601DateFormatter()
        internetFormatter.formatOptions = [.withInternetDateTime]

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let localFormatter = DateFormatter()
        localFormatter.calendar = Calendar(identifier: .iso8601)
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        localFormatter.timeZone = TimeZone.current

        return internetFormatter.date(from: string)
            ?? fractionalFormatter.date(from: string)
            ?? localFormatter.date(from: string)
    }

    nonisolated private static func weekdayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "today"
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "tomorrow"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private struct Candidate {
        let window: BestWindow
        let score: Int
    }

    private struct WindowMetrics {
        let waveHeightMeters: Double
        let periodSeconds: Double
        let windSpeedKmh: Double
    }
}
