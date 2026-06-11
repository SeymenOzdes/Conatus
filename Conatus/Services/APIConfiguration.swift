import Foundation

struct APIConfiguration: Equatable {
    nonisolated static let environmentOverrideKey = "CONATUS_API_BASE_URL"

    nonisolated static var current: APIConfiguration {
        APIConfiguration(baseURL: resolvedBaseURL())
    }

    let baseURL: URL

    nonisolated private static let productionBaseURL = URL(string: "https://api.conatus.app")!
    nonisolated private static let simulatorDevelopmentBaseURL = URL(string: "http://127.0.0.1:8000")!

    nonisolated private static func resolvedBaseURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = environment[environmentOverrideKey],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let url = validatedBaseURL(from: override) {
                return url
            }

            #if DEBUG
            assertionFailure("Invalid \(environmentOverrideKey): \(override)")
            #endif
        }

        #if DEBUG && targetEnvironment(simulator)
        return simulatorDevelopmentBaseURL
        #else
        return productionBaseURL
        #endif
    }

    nonisolated private static func validatedBaseURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return nil
        }
        return url
    }
}
