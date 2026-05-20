//
//  StartSessionPresenter.swift
//  Conatus
//
//  Drives the "Start a Session" bottom sheet — a 3-step flow: pick a location,
//  enter session details, review and save. Modeled on AddSpotPresenter so the
//  sheet's mount/dismount stays declarative.
//

import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class StartSessionPresenter {

    enum Step: Int, CaseIterable {
        case location, details, summary
    }

    /// A spot picked for the session — either from search (has spotId) or from
    /// the user's pinned list (uses the local Spot UUID via `localId`).
    struct PickedSpot: Equatable {
        let spotId: String?
        let localId: UUID?
        let name: String
        let latitude: Double
        let longitude: Double
    }

    // Presentation
    var isPresented: Bool = false
    var step: Step = .location
    /// Fires when `present()` is called, so the host can dismiss any sibling sheet.
    var onPresent: (() -> Void)?
    /// Fires when `dismiss()` is called, so the host can disable the backdrop's
    /// hit-testing UIView (SwiftUI's `allowsHitTesting` doesn't propagate to the
    /// underlying UIHostingController view).
    var onDismiss: (() -> Void)?

    // Form state
    var pickedSpot: PickedSpot?
    var waveCount: Int = 0
    var startedAt: Date = Date().addingTimeInterval(-3600)
    var endedAt: Date = Date()
    var boardType: BoardType = .shortboard
    var waveSize: WaveSize = .waist
    var crowdLevel: CrowdLevel = .moderate
    var rating: Int = 4
    var notes: String = ""

    // Reuse the existing search pipeline for location picking.
    let searchVM = SpotSearchViewModel()

    var canContinue: Bool {
        switch step {
        case .location: return pickedSpot != nil
        case .details:  return endedAt > startedAt && waveCount >= 0
        case .summary:  return canSave
        }
    }

    var canSave: Bool {
        pickedSpot != nil && endedAt > startedAt
    }

    // MARK: - Lifecycle

    func present() {
        reset()
        onPresent?()
        isPresented = true
    }

    func dismiss() {
        isPresented = false
        onDismiss?()
    }

    // MARK: - Navigation

    func goNext() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func goBack() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    // MARK: - Location

    func pick(_ result: SpotResult) {
        pickedSpot = PickedSpot(
            spotId: result.spotId,
            localId: nil,
            name: result.name,
            latitude: result.lat,
            longitude: result.lng
        )
        searchVM.query = result.name
    }

    func pick(_ spot: Spot) {
        pickedSpot = PickedSpot(
            spotId: nil,
            localId: spot.id,
            name: spot.name,
            latitude: spot.coordinate.latitude,
            longitude: spot.coordinate.longitude
        )
        searchVM.query = spot.name
    }

    func clearPickedLocation() {
        pickedSpot = nil
        searchVM.query = ""
    }

    // MARK: - Build

    func buildSession() -> UserSession? {
        guard canSave, let picked = pickedSpot else { return nil }
        return UserSession(
            id: UUID(),
            spotId: picked.spotId,
            spotName: picked.name,
            latitude: picked.latitude,
            longitude: picked.longitude,
            startedAt: startedAt,
            endedAt: endedAt,
            waveCount: waveCount,
            boardType: boardType,
            waveSize: waveSize,
            crowdLevel: crowdLevel,
            rating: rating,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )
    }

    private func reset() {
        step = .location
        pickedSpot = nil
        waveCount = 0
        startedAt = Date().addingTimeInterval(-3600)
        endedAt = Date()
        boardType = .shortboard
        waveSize = .waist
        crowdLevel = .moderate
        rating = 4
        notes = ""
        searchVM.query = ""
    }
}
