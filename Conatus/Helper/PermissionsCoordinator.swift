//
//  PermissionsCoordinator.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import Foundation
import CoreLocation
import HealthKit
import UserNotifications

@MainActor
final class PermissionsCoordinator: NSObject {
    typealias GrantState = UserPreferences.GrantState

    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<GrantState, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    // MARK: - Location

    func requestLocation() async -> GrantState {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                locationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return .denied
        }
    }

    // MARK: - Health

    func requestHealth() async -> GrantState {
        guard HKHealthStore.isHealthDataAvailable() else { return .denied }
        guard
            let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
            let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        else {
            return .denied
        }
        let readTypes: Set<HKObjectType> = [HKObjectType.workoutType(), heartRate, activeEnergy]
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            // HealthKit deliberately doesn't expose read-auth state; assume granted if no error.
            return .granted
        } catch {
            return .denied
        }
    }

    // MARK: - Notifications

    func requestNotifications() async -> GrantState {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PermissionsCoordinator: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined, let continuation = locationContinuation else { return }
            locationContinuation = nil
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                continuation.resume(returning: .granted)
            default:
                continuation.resume(returning: .denied)
            }
        }
    }
}
