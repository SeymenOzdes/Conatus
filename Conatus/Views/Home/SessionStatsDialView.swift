//
//  SessionStatsDialView.swift
//  Conatus
//

import SwiftUI

struct SessionStatsDialView: View {

    // MARK: - Placeholder values (no backing data yet)

    private let totalHours = 7
    private let totalMinutes = 42
    private let deltaPercent = 18           // negative = down
    private let weekNumber = 19
    private let wavesCaught = 57
    private let longestSeconds = 38
    private let spotsCount = 4

    private let accent = Color(red: 0.0, green: 0.74, blue: 0.74)
    private let warn   = Color(red: 1.0, green: 0.55, blue: 0.20)
    private let downRed = Color(red: 0.96, green: 0.32, blue: 0.25)

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            dial
                .frame(width: 150, height: 150)
            stats
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Dial

    private var dial: some View {
        ZStack {
            TickRing(filledCount: 38, warnCount: 6, totalTicks: 60,
                     filledColor: accent, warnColor: warn,
                     idleColor: Color.primary.opacity(0.12))

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(totalHours)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text("H")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(totalMinutes)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .padding(.leading, 4)
                    Text("M")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(deltaPercent)%")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(downRed)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(downRed.opacity(0.12)))
            }
        }
    }

    // MARK: - Stats grid

    private var stats: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEEK \(weekNumber)")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)

            Text("\(wavesCaught) waves\ncaught.")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineSpacing(0)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 24) {
                statCell(label: "Longest", value: "\(longestSeconds)s")
                statCell(label: "Spots",   value: "\(spotsCount)")
            }
            .padding(.top, 2)
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Tick Ring

private struct TickRing: View {
    let filledCount: Int
    let warnCount: Int
    let totalTicks: Int
    let filledColor: Color
    let warnColor: Color
    let idleColor: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2
            let inner = outer - 10
            let tickWidth: CGFloat = 1.8

            for i in 0..<totalTicks {
                let angle = (Double(i) / Double(totalTicks)) * 2 * .pi - .pi / 2
                let start = CGPoint(
                    x: center.x + cos(angle) * inner,
                    y: center.y + sin(angle) * inner
                )
                let end = CGPoint(
                    x: center.x + cos(angle) * outer,
                    y: center.y + sin(angle) * outer
                )
                let color: Color
                if i < filledCount {
                    color = filledColor
                } else if i < filledCount + warnCount {
                    color = warnColor
                } else {
                    color = idleColor
                }
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: tickWidth, lineCap: .round))
            }
        }
    }
}
