//
//  UserSessionsRepository.swift
//  Conatus
//
//  Local persistence for logged surf sessions. Mirrors UserSpotsRepository:
//  UserDefaults-backed for MVP; swap for a file/SQLite store if the list grows.
//

import Foundation

@MainActor
final class UserSessionsRepository {
    static let shared = UserSessionsRepository()

    private let defaults: UserDefaults
    private let key = "me.ozdes.seymen.Conatus.userSessions.v1"

    private(set) var sessions: [UserSession] = []
    var onChange: (([UserSession]) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ session: UserSession) {
        sessions.append(session)
        save()
        onChange?(sessions)
    }

    func all() -> [UserSession] { sessions }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        do {
            sessions = try JSONDecoder().decode([UserSession].self, from: data)
        } catch {
            sessions = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(sessions)
            defaults.set(data, forKey: key)
        } catch {
            // Non-fatal: in-memory list still works for this session.
        }
    }
}
