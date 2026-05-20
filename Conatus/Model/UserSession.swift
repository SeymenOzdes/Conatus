//
//  UserSession.swift
//  Conatus
//
//  Locally-logged surf session. Mirrors UserSpot's flat-Codable shape so the
//  same UserDefaults round-trip pattern works.
//

import Foundation

struct UserSession: Codable, Identifiable, Hashable {
    let id: UUID
    let spotId: String?
    let spotName: String
    let latitude: Double
    let longitude: Double
    let startedAt: Date
    let endedAt: Date
    let waveCount: Int
    let boardType: BoardType
    let waveSize: WaveSize
    let crowdLevel: CrowdLevel
    let rating: Int
    let notes: String
    let createdAt: Date
}

enum BoardType: String, Codable, CaseIterable, Hashable {
    case shortboard, longboard, fish, funboard, foil, other

    var displayName: String {
        switch self {
        case .shortboard: return "Shortboard"
        case .longboard:  return "Longboard"
        case .fish:       return "Fish"
        case .funboard:   return "Funboard"
        case .foil:       return "Foil"
        case .other:      return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .shortboard: return "bolt.fill"
        case .longboard:  return "ruler.fill"
        case .fish:       return "fish.fill"
        case .funboard:   return "face.smiling.fill"
        case .foil:       return "airplane"
        case .other:      return "square.grid.2x2.fill"
        }
    }
}

enum WaveSize: String, Codable, CaseIterable, Hashable {
    case ankle, knee, waist, chest, head, overhead

    var displayName: String {
        switch self {
        case .ankle:    return "Ankle"
        case .knee:     return "Knee"
        case .waist:    return "Waist"
        case .chest:    return "Chest"
        case .head:     return "Head"
        case .overhead: return "Overhead"
        }
    }

    var iconName: String {
        switch self {
        case .ankle:    return "1.circle.fill"
        case .knee:     return "2.circle.fill"
        case .waist:    return "3.circle.fill"
        case .chest:    return "4.circle.fill"
        case .head:     return "5.circle.fill"
        case .overhead: return "6.circle.fill"
        }
    }
}

enum CrowdLevel: String, Codable, CaseIterable, Hashable {
    case empty, light, moderate, crowded

    var displayName: String {
        switch self {
        case .empty:    return "Empty"
        case .light:    return "Light"
        case .moderate: return "Moderate"
        case .crowded:  return "Crowded"
        }
    }

    var iconName: String {
        switch self {
        case .empty:    return "person"
        case .light:    return "person.2.fill"
        case .moderate: return "person.3.fill"
        case .crowded:  return "person.3.sequence.fill"
        }
    }
}

extension UserSession {
    var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }

    var durationLabel: String {
        let total = Int(duration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}
