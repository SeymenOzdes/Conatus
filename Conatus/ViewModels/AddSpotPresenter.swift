//
//  AddSpotPresenter.swift
//  Conatus
//
//  Drives the Add Spot bottom sheet. Form state + presentation flag live here
//  so the sheet's mount/dismount stays declarative.
//

import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class AddSpotPresenter {

    // Presentation
    var isPresented: Bool = false
    /// Fires when `present()` is called, so the host can dismiss any sibling sheet.
    var onPresent: (() -> Void)?

    // Form state
    var name: String = ""
    var pickedResult: SpotResult?
    var mapCenterCoordinate: CLLocationCoordinate2D?

    // Reuse the existing search pipeline for location picking.
    let searchVM = SpotSearchViewModel()

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (pickedResult != nil || mapCenterCoordinate != nil)
    }

    func present() {
        reset()
        onPresent?()
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    func pick(_ result: SpotResult) {
        pickedResult = result
        searchVM.query = result.name
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = result.name
        }
    }

    func clearPickedLocation() {
        pickedResult = nil
        searchVM.query = ""
    }

    func updateMapCenterCoordinate(_ coordinate: CLLocationCoordinate2D) {
        mapCenterCoordinate = coordinate
    }

    func buildUserSpot() -> UserSpot? {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard canSave, !trimmedName.isEmpty else { return nil }

        if let result = pickedResult {
            return UserSpot(
                id: UUID(),
                name: trimmedName,
                latitude: result.lat,
                longitude: result.lng,
                breakType: result.breakType ?? "",
                country: result.region ?? result.country,
                createdAt: Date()
            )
        }

        guard let coordinate = mapCenterCoordinate else { return nil }
        return UserSpot(
            id: UUID(),
            name: trimmedName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            breakType: "",
            country: nil,
            createdAt: Date()
        )
    }

    private func reset() {
        name = ""
        pickedResult = nil
        mapCenterCoordinate = nil
        searchVM.query = ""
    }
}
