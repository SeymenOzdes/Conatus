//
//  UserSpotsRepository.swift
//  Conatus
//
//  Local persistence for user-added spots. UserDefaults-backed for MVP;
//  swap for a file/SQLite store if the list grows large.
//

import Foundation

struct UserSpot: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let breakType: String
    let country: String?
    let createdAt: Date
}

@MainActor
final class UserSpotsRepository {
    static let shared = UserSpotsRepository()

    private let defaults: UserDefaults
    private let key = "me.ozdes.seymen.Conatus.userSpots.v1"

    private(set) var spots: [UserSpot] = []
    var onChange: (([UserSpot]) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ spot: UserSpot) {
        spots.append(spot)
        save()
        onChange?(spots)
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        do {
            spots = try JSONDecoder().decode([UserSpot].self, from: data)
        } catch {
            spots = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(spots)
            defaults.set(data, forKey: key)
        } catch {
            // Persistence failure is non-fatal: in-memory list still works for this session.
        }
    }
}
