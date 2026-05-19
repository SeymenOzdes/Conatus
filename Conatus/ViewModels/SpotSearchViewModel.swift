//
//  SpotSearchViewModel.swift
//  Conatus
//
//  Created by Seymen Özdeş on 11.05.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class SpotSearchViewModel {

    enum Phase: Equatable {
        case idle
        case loading
        case results([SpotResult])
        case empty
        case failed(String)
    }

    var query: String = ""
    private(set) var phase: Phase = .idle

    private let service: SearchService
    private let debounce: Duration
    private let minQueryLength: Int
    private var searchTask: Task<Void, Never>?

    init(service: SearchService = SearchService(),
         debounce: Duration = .milliseconds(300),
         minQueryLength: Int = 2) {
        self.service = service
        self.debounce = debounce
        self.minQueryLength = minQueryLength
    }

    func onQueryChanged() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minQueryLength else {
            phase = .idle
            return
        }

        phase = .loading
        searchTask = Task { [debounce, service, weak self] in
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            do {
                let results = try await service.search(query: trimmed, limit: 8)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    guard self.query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                    self.phase = results.isEmpty ? .empty : .results(results)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    guard self.query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                    self.phase = .failed(Self.message(for: error))
                }
            }
        }
    }

    func result(forID id: String) -> SpotResult? {
        guard case let .results(items) = phase else { return nil }
        return items.first { $0.spotId == id }
    }

    private static func message(for error: Error) -> String {
        guard let error = error as? SearchServiceError else {
            return "Something went wrong"
        }
        switch error {
        case .invalidURL:       return "Couldn't build request"
        case .transport:        return "No connection"
        case .badStatus:        return "Server error"
        case .decoding:         return "Couldn't read response"
        }
    }
}
