//
//  AddSpotPresenter.swift
//  Conatus
//
//  Drives the Add Spot bottom sheet. Form state + presentation flag live here
//  so the sheet's mount/dismount stays declarative.
//

import Foundation
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

    // Reuse the existing search pipeline for location picking.
    let searchVM = SpotSearchViewModel()

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && pickedResult != nil
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

    func buildUserSpot() -> UserSpot? {
        guard canSave, let result = pickedResult else { return nil }
        return UserSpot(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            latitude: result.lat,
            longitude: result.lng,
            breakType: result.breakType ?? "",
            country: result.country,
            createdAt: Date()
        )
    }

    private func reset() {
        name = ""
        pickedResult = nil
        searchVM.query = ""
    }
}
