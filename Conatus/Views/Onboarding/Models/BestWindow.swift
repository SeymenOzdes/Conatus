//
//  BestWindow.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import Foundation

struct BestWindow: Identifiable {
    let id = UUID()
    let spotID: UUID
    let spotName: String
    let weekday: String
    let startHour: Date
    let endHour: Date
    let waveHeightMeters: Double
    let periodSeconds: Double
    let windSpeedKmh: Double
    var summaryText: String
}
