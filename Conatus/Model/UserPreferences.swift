//
//  UserPreferences.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import Foundation

struct UserPreferences: Codable, Sendable {
    var name: String?
    var persona: Persona?
    var pinnedSpotIDs: [UUID]
    var heightDisplay: HeightDisplay?
    var units: Units?
    var permissions: PermissionStatuses
    var hasCompletedOnboarding: Bool

    enum Persona: String, Codable, Sendable, CaseIterable {
        case beginner, intermediate, advanced
    }

    enum HeightDisplay: String, Codable, Sendable, CaseIterable {
        case waveFace, swellHeight
    }

    enum Units: String, Codable, Sendable, CaseIterable {
        case imperial, metric
    }

    enum GrantState: String, Codable, Sendable {
        case notDetermined, granted, denied, skipped
    }

    struct PermissionStatuses: Codable, Sendable {
        var location: GrantState = .notDetermined
        var health: GrantState = .notDetermined
        var notifications: GrantState = .notDetermined
    }

    static let `default` = UserPreferences(
        name: nil,
        persona: nil,
        pinnedSpotIDs: [],
        heightDisplay: nil,
        units: nil,
        permissions: PermissionStatuses(),
        hasCompletedOnboarding: false
    )
}

// MARK: - Persistence

extension UserPreferences {
    static let onboardingFlagKey = "hasCompletedOnboarding"
    private static let storageKey = "userPreferences"

    static var current: UserPreferences {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let value = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else {
            return .default
        }
        return value
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingFlagKey)
    }
}
