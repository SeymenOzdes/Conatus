//
//  AppLaunchConfiguration.swift
//  Conatus
//
//  Created by Codex on 02.06.2026.
//

import Foundation

enum AppLaunchConfiguration {
    /// Flip this for local testing:
    /// - true: app opens with onboarding every launch
    /// - false: app opens with the main menu unless onboarding has not been completed
    static let forceStartWithOnboarding = false

    static var shouldStartWithOnboarding: Bool {
        forceStartWithOnboarding || !UserPreferences.current.hasCompletedOnboarding
    }
}
