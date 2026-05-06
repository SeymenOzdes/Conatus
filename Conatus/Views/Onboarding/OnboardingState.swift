//
//  OnboardingState.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import Foundation
import Observation

@Observable
@MainActor
final class OnboardingState {
    typealias Persona = UserPreferences.Persona
    typealias HeightDisplay = UserPreferences.HeightDisplay
    typealias Units = UserPreferences.Units
    typealias GrantState = UserPreferences.GrantState
    typealias PermissionStatuses = UserPreferences.PermissionStatuses

    let totalSteps: Int = 9
    var currentStep: Int = 0
    private(set) var isGoingBack: Bool = false

    var name: String = ""
    var persona: Persona?
    var pinnedSpotIDs: Set<UUID> = []
    var heightDisplay: HeightDisplay?
    var units: Units?
    var permissions = PermissionStatuses()
    var bestWindow: BestWindow?

    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    // MARK: - Navigation

    var canAdvance: Bool {
        switch currentStep {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return persona != nil
        case 2: return !pinnedSpotIDs.isEmpty
        case 3: return heightDisplay != nil
        case 4: return units != nil
        case 5, 6, 7, 8: return true
        default: return false
        }
    }

    var canGoBack: Bool {
        currentStep > 0 && currentStep < totalSteps - 1
    }

    func next() {
        guard canAdvance else { return }
        if currentStep == totalSteps - 1 {
            complete()
        } else {
            isGoingBack = false
            currentStep += 1
        }
    }

    func back() {
        guard canGoBack else { return }
        isGoingBack = true
        currentStep -= 1
    }

    // MARK: - Selection helpers

    func togglePinnedSpot(_ id: UUID) {
        if pinnedSpotIDs.contains(id) {
            pinnedSpotIDs.remove(id)
        } else if pinnedSpotIDs.count < 3 {
            pinnedSpotIDs.insert(id)
        }
    }

    var pinnedSpotsAtMax: Bool { pinnedSpotIDs.count >= 3 }

    // MARK: - Completion

    func complete() {
        var prefs = UserPreferences.default
        prefs.name = name.trimmingCharacters(in: .whitespaces)
        prefs.persona = persona
        prefs.pinnedSpotIDs = Array(pinnedSpotIDs)
        prefs.heightDisplay = heightDisplay
        prefs.units = units
        prefs.permissions = permissions
        prefs.hasCompletedOnboarding = true
        prefs.save()
        onComplete()
    }
}
