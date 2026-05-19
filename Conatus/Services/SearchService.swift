import Foundation

struct SpotResult: Decodable, Identifiable, Hashable {
    let spotId: String
    let name: String
    let lat: Double
    let lng: Double
    let breakType: String?
    let country: String?
    let distanceM: Int?

    var id: String { spotId }

    enum CodingKeys: String, CodingKey {
        case spotId = "spot_id"
        case name, lat, lng
        case breakType = "break_type"
        case country
        case distanceM = "distance_m"
    }
}

private struct SearchResponseDTO: Decodable {
    let spots: [SpotResult]
}

enum SearchServiceError: Error {
    case invalidURL
    case badStatus(Int)
    case decoding(Error)
    case transport(Error)
}

struct SearchService {
    static let baseURL = URL(string: "http://localhost:8000")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, limit: Int = 10) async throws -> [SpotResult] {
        try await fetch(items: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func searchNearby(lat: Double,
                      lng: Double,
                      radiusMeters: Int = 30_000,
                      limit: Int = 10) async throws -> [SpotResult] {
        try await fetch(items: [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "radius", value: String(radiusMeters)),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    private func fetch(items: [URLQueryItem]) async throws -> [SpotResult] {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("/v1/spots/search"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = items
        guard let url = components?.url else {
            throw SearchServiceError.invalidURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw SearchServiceError.transport(error)
        }

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw SearchServiceError.badStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(SearchResponseDTO.self, from: data).spots
        } catch {
            throw SearchServiceError.decoding(error)
        }
    }
}
