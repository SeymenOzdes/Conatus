//
//  SearchSuggestionsView.swift
//  Conatus
//
//  Created by Seymen Özdeş on 29.04.2026.
//

import SwiftUI

struct SuggestionRow: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String?
    let symbol: String
    let tint: Color
    let distanceM: Int?

    init(
        id: String,
        name: String,
        subtitle: String?,
        symbol: String,
        tint: Color,
        distanceM: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.distanceM = distanceM
    }
}

struct SearchSuggestionsView: View {
    private enum Content {
        case loading
        case rows([SuggestionRow])
        case empty
        case failed(String)
    }

    private let content: Content
    private let query: String
    private let onSelect: (String) -> Void

    init(
        phase: SpotSearchViewModel.Phase,
        query: String = "",
        onSelect: @escaping (String) -> Void
    ) {
        switch phase {
        case .idle:
            self.content = .rows([])
        case .loading:
            self.content = .loading
        case .empty:
            self.content = .empty
        case .failed(let message):
            self.content = .failed(message)
        case .results(let results):
            self.content = .rows(results.map(SuggestionRow.init(result:)))
        }
        self.query = query
        self.onSelect = onSelect
    }

    init(rows: [SuggestionRow], onSelect: @escaping (String) -> Void) {
        self.content = .rows(rows)
        self.query = ""
        self.onSelect = onSelect
    }

    init(spots: [Spot], onSelect: @escaping (Spot) -> Void) {
        let rows = spots.map { spot in
            SuggestionRow(
                id: spot.id.uuidString,
                name: spot.name,
                subtitle: nil,
                symbol: spot.symbol,
                tint: spot.tint
            )
        }
        self.content = .rows(rows)
        self.query = ""
        self.onSelect = { id in
            guard let spot = spots.first(where: { $0.id.uuidString == id }) else { return }
            onSelect(spot)
        }
    }

    var body: some View {
        Group {
            switch content {
            case .loading:
                statusRow {
                    ProgressView().controlSize(.small)
                    Text("Searching…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            case .empty:
                statusRow {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text("No spots found")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            case .failed(let message):
                statusRow {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            case .rows(let rows):
                if rows.isEmpty {
                    EmptyView()
                } else {
                    rowList(rows)
                }
            }
        }
    }

    private func rowList(_ rows: [SuggestionRow]) -> some View {
        let nearCityLabel = geocodeHeaderLabel(for: rows)

        return VStack(spacing: 0) {
            if let nearCityLabel {
                headerRow(text: nearCityLabel)
                Divider()
                    .opacity(0.22)
            }

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                Button {
                    onSelect(row.id)
                } label: {
                    rowView(for: row)
                }
                .buttonStyle(SuggestionRowButtonStyle())
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .animation(.easeOut(duration: 0.22).delay(Double(index) * 0.035)),
                        removal: .opacity.animation(.easeOut(duration: 0.12))
                    )
                )

                if index < rows.count - 1 {
                    Divider()
                        .opacity(0.22)
                }
            }
        }
        .padding(.vertical, 4)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func geocodeHeaderLabel(for rows: [SuggestionRow]) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rows.isEmpty,
              !trimmed.isEmpty,
              rows.allSatisfy({ $0.distanceM != nil })
        else { return nil }
        return "Spots near \(trimmed)"
    }

    private func headerRow(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .accessibilityAddTraits(.isHeader)
    }

    private func rowView(for row: SuggestionRow) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(row.tint.opacity(0.18))
                    .frame(width: 24, height: 24)
                Image(systemName: row.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(row.tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                if let subtitle = row.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if let distance = row.distanceM {
                Text(Self.distanceString(distance))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .accessibilityLabel("\(distance / 1000) kilometers away")
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private static func distanceString(_ meters: Int) -> String {
        if meters < 1000 {
            return "\(meters) m"
        }
        let km = Double(meters) / 1000
        if km < 10 {
            return String(format: "%.1f km", km)
        }
        return "\(Int(km.rounded())) km"
    }

    @ViewBuilder
    private func statusRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SuggestionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension SuggestionRow {
    init(result: SpotResult) {
        let subtitle = [result.country, result.breakType?.capitalized]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        self.init(
            id: result.spotId,
            name: result.name,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            symbol: Self.symbol(for: result.breakType),
            tint: Self.tint(for: result.breakType),
            distanceM: result.distanceM
        )
    }

    private static func symbol(for breakType: String?) -> String {
        switch breakType?.lowercased() {
        case "reef":  return "water.waves"
        case "point": return "mappin.and.ellipse"
        case "beach": return "beach.umbrella.fill"
        case "river": return "water.waves.and.arrow.trianglehead.down"
        default:      return "figure.surfing"
        }
    }

    private static func tint(for breakType: String?) -> Color {
        switch breakType?.lowercased() {
        case "reef":  return .indigo
        case "point": return .orange
        case "beach": return .teal
        case "river": return .cyan
        default:      return .blue
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.cyan.opacity(0.5), .blue.opacity(0.4)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        SearchSuggestionsView(spots: Spot.samples) { _ in }
            .padding(.horizontal, 16)
    }
}
