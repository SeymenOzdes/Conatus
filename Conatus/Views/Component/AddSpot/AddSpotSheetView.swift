//
//  AddSpotSheetView.swift
//  Conatus
//

import SwiftUI

struct AddSpotSheetView: View {
    @Bindable var presenter: AddSpotPresenter
    var onSave: (UserSpot) -> Void
    var onClose: () -> Void

    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            nameField

            locationSection

            saveButton
        }
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.spring(duration: 0.32, bounce: 0.18), value: presenter.pickedResult?.spotId)
        .animation(.spring(duration: 0.28, bounce: 0.15), value: presenter.searchVM.phase)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            Text("Add Spot")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Name")
            TextField("e.g. Mavericks", text: $presenter.name)
                .font(.system(size: 16))
                .focused($nameFocused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .glassEffect(.regular, in: .capsule)
        }
    }

    private var locationSection: some View {
        // Bind directly to the search VM so its $query produces a writable Binding.
        @Bindable var searchVM = presenter.searchVM
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Location")
            if let picked = presenter.pickedResult {
                pickedLocationRow(for: picked)
            } else {
                SearchBarView(text: $searchVM.query, placeholder: "Search by city or spot")
                    .onChange(of: searchVM.query) { _, _ in
                        searchVM.onQueryChanged()
                    }
                SearchSuggestionsView(phase: searchVM.phase, query: searchVM.query) { id in
                    guard let result = searchVM.result(forID: id) else { return }
                    nameFocused = false
                    presenter.pick(result)
                }
                .transition(.opacity)
            }
        }
    }

    private func pickedLocationRow(for result: SpotResult) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(coordinateLabel(for: result))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Button {
                presenter.clearPickedLocation()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change location")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var saveButton: some View {
        OnboardingPrimaryButton(
            title: "Save Spot",
            isEnabled: presenter.canSave
        ) {
            guard let spot = presenter.buildUserSpot() else { return }
            onSave(spot)
        }
        .padding(.horizontal, -24) // Cancel the OnboardingPrimaryButton's internal 24pt inset
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .tracking(0.6)
    }

    private func coordinateLabel(for result: SpotResult) -> String {
        let lat = String(format: "%.4f", result.lat)
        let lng = String(format: "%.4f", result.lng)
        if let country = result.country, !country.isEmpty {
            return "\(country) · \(lat), \(lng)"
        }
        return "\(lat), \(lng)"
    }
}
