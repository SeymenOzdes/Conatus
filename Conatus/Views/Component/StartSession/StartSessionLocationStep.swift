//
//  StartSessionLocationStep.swift
//  Conatus
//

import SwiftUI

struct StartSessionLocationStep: View {
    @Bindable var presenter: StartSessionPresenter
    let pinnedSpots: [Spot]

    var body: some View {
        @Bindable var searchVM = presenter.searchVM

        VStack(alignment: .leading, spacing: 12) {
            if let picked = presenter.pickedSpot {
                pickedRow(for: picked)
            } else {
                SearchBarView(text: $searchVM.query, placeholder: "Search by city or spot")
                    .onChange(of: searchVM.query) { _, _ in
                        searchVM.onQueryChanged()
                    }

                SearchSuggestionsView(phase: searchVM.phase, query: searchVM.query) { id in
                    guard let result = searchVM.result(forID: id) else { return }
                    presenter.pick(result)
                }
                .transition(.opacity)

                if shouldShowPinned {
                    pinnedSection
                }
            }
        }
    }

    private var shouldShowPinned: Bool {
        !pinnedSpots.isEmpty && presenter.searchVM.query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PINNED")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.white.opacity(0.65))
                .padding(.top, 4)

            SearchSuggestionsView(spots: pinnedSpots) { spot in
                presenter.pick(spot)
            }
        }
    }

    private func pickedRow(for picked: StartSessionPresenter.PickedSpot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 1) {
                Text(picked.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Text(coordinateLabel(for: picked))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Button {
                presenter.clearPickedLocation()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change location")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func coordinateLabel(for picked: StartSessionPresenter.PickedSpot) -> String {
        let lat = String(format: "%.4f", picked.latitude)
        let lng = String(format: "%.4f", picked.longitude)
        return "\(lat), \(lng)"
    }
}
