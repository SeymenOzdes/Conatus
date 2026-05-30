//
//  FavoriteSpotCardsSection.swift
//  Conatus
//

import SwiftUI

struct FavoriteSpotCardsSection: View {
    let spots: [Spot]
    let units: UserPreferences.Units
    var onSelect: (Spot) -> Void

    var body: some View {
        if spots.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("FAVORITE SPOTS")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                GeometryReader { proxy in
                    let cardWidth = min(proxy.size.width - 48, 320)

                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            ForEach(spots) { spot in
                                FavoriteSpotCard(
                                    spot: spot,
                                    units: units,
                                    width: cardWidth,
                                    onTap: { onSelect(spot) }
                                )
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                    .padding(.horizontal, -16)
                }
                .frame(height: 362)
            }
        }
    }
}

private struct FavoriteSpotCard: View {
    let spot: Spot
    let units: UserPreferences.Units
    let width: CGFloat
    var onTap: () -> Void

    private let cornerRadius: CGFloat = 28
    private let imageHeight: CGFloat = 218

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                SpotArtworkView(spot: spot)
                    .frame(height: imageHeight)
                    .overlay(alignment: .topTrailing) {
                        bookmarkBadge
                            .padding(18)
                    }

                VStack(alignment: .leading, spacing: 12) {
                    Text(spot.name)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    HStack(alignment: .center, spacing: 8) {
                        FavoriteSpotStatusBadge(status: spot.surfStatus)

                        Text(spot.displayedWaveRange(units: units))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("•")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))

                        Text("\(Int(round(spot.waterTempC)))° water")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                    }

                    Text(detailLine)
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)

                    Text(conditionsLine)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.12, green: 0.13, blue: 0.12))
            }
            .frame(width: width, height: 352, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.13, blue: 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 26, x: 0, y: 16)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(FavoriteSpotCardButtonStyle())
        .accessibilityLabel("\(spot.name), \(spot.displayedWaveRange(units: units)), \(spot.surfStatus.label)")
    }

    private var detailLine: String {
        if let subtitle = spot.subtitle, !subtitle.isEmpty {
            return subtitle
        }
        return spot.weather.condition.label
    }

    private var conditionsLine: String {
        let wind = Int(round(spot.wind.speedKmh))
        return "\(spot.weather.condition.label) • \(wind) km/h wind"
    }

    private var bookmarkBadge: some View {
        Image(systemName: "bookmark")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
            .accessibilityHidden(true)
    }
}

private struct SpotArtworkView: View {
    let spot: Spot

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                sky
                sunGlow
                distantCoastline(size: proxy.size)
                sea
                waveBands(size: proxy.size)
                symbolMark
                vignette
            }
            .clipped()
        }
    }

    private var sky: some View {
        LinearGradient(
            colors: [
                spot.tint.opacity(0.46),
                Color(red: 0.62, green: 0.86, blue: 0.90),
                Color(red: 0.98, green: 0.86, blue: 0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sunGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.88),
                        Color.orange.opacity(0.28),
                        .clear
                    ],
                    center: .center,
                    startRadius: 8,
                    endRadius: 116
                )
            )
            .frame(width: 232, height: 232)
            .offset(x: 96, y: -78)
            .blur(radius: 2)
    }

    private func distantCoastline(size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.10))
                .frame(height: 1)
                .offset(y: -6)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.black.opacity(0.12))
                        .frame(
                            width: CGFloat([10, 15, 8, 18, 12, 24, 9, 14, 18, 11][index]),
                            height: CGFloat([10, 24, 15, 42, 26, 58, 20, 32, 22, 16][index])
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 34)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .offset(y: size.height * 0.08)
    }

    private var sea: some View {
        LinearGradient(
            colors: [
                spot.tint.opacity(0.18),
                Color(red: 0.05, green: 0.48, blue: 0.58),
                Color(red: 0.02, green: 0.28, blue: 0.34)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .mask(
            Rectangle()
                .padding(.top, 102)
        )
    }

    private func waveBands(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                WaveStripe(phase: CGFloat(index) * 0.72)
                    .stroke(.white.opacity(0.18 - Double(index) * 0.012), lineWidth: index < 2 ? 1.2 : 0.8)
                    .frame(height: 18)
                    .offset(
                        x: CGFloat(index % 2 == 0 ? -18 : 28),
                        y: size.height * 0.46 + CGFloat(index * 15)
                    )
            }
        }
    }

    private var symbolMark: some View {
        Image(systemName: spot.symbol)
            .font(.system(size: 42, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white.opacity(0.78))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(22)
            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
    }

    private var vignette: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.20),
                .clear,
                .black.opacity(0.26)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct WaveStripe: Shape {
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amplitude = rect.height * 0.28
        let midY = rect.midY
        let wavelength = rect.width / 1.7

        path.move(to: CGPoint(x: rect.minX, y: midY))
        stride(from: rect.minX, through: rect.maxX, by: 6).forEach { x in
            let progress = (x / wavelength) + phase
            let y = midY + sin(progress * .pi * 2) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

private struct FavoriteSpotStatusBadge: View {
    let status: Spot.SurfStatus

    var body: some View {
        Text(status.label.capitalized)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(status.color.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(status.color.opacity(0.78), lineWidth: 1)
            )
    }
}

private struct FavoriteSpotCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.22, bounce: 0.24), value: configuration.isPressed)
    }
}
