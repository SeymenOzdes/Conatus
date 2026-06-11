//
//  SettingsContentView.swift
//  Conatus
//
//  Created by Codex on 11.06.2026.
//

import StoreKit
import SwiftUI
import UIKit

@Observable
@MainActor
final class SettingsViewModel {
    var preferences: UserPreferences
    var nameDraft: String
    var hasActiveSubscription = false
    var isCheckingSubscription = false
    var isRestoringPurchases = false
    var showingPlans = false
    var showingManageSubscriptions = false
    var alert: SettingsAlert?

    private let subscriptionStore = SubscriptionStore()

    init() {
        let preferences = UserPreferences.current
        self.preferences = preferences
        self.nameDraft = preferences.name ?? ""
    }

    init(preferences: UserPreferences) {
        self.preferences = preferences
        self.nameDraft = preferences.name ?? ""
    }

    func refreshFromStorage() {
        let stored = UserPreferences.current
        preferences = stored
        nameDraft = stored.name ?? ""
    }

    func commitNameDraft() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextName = trimmed.isEmpty ? nil : trimmed
        guard preferences.name != nextName else { return }
        preferences.name = nextName
        savePreferences()
    }

    func updatePersona(_ persona: UserPreferences.Persona) {
        guard preferences.persona != persona else { return }
        preferences.persona = persona
        savePreferences()
    }

    func updateUnits(_ units: UserPreferences.Units) {
        guard preferences.units != units else { return }
        preferences.units = units
        savePreferences()
    }

    func updateHeightDisplay(_ heightDisplay: UserPreferences.HeightDisplay) {
        guard preferences.heightDisplay != heightDisplay else { return }
        preferences.heightDisplay = heightDisplay
        savePreferences()
    }

    func refreshSubscriptionStatus(force: Bool = false) async {
        guard force || !isCheckingSubscription else { return }
        isCheckingSubscription = true
        defer { isCheckingSubscription = false }

        hasActiveSubscription = await subscriptionStore.hasActiveSubscription()
    }

    func restorePurchases() async {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await subscriptionStore.restorePurchases()
            hasActiveSubscription = true
            alert = SettingsAlert(
                title: "Purchases restored",
                message: "Your Conatus Pro access is active on this Apple ID."
            )
        } catch {
            hasActiveSubscription = await subscriptionStore.hasActiveSubscription()
            alert = SettingsAlert(
                title: "No purchases to restore",
                message: error.localizedDescription
            )
        }
    }

    private func savePreferences() {
        preferences.save()
    }
}

struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct SettingsContentView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.openURL) private var openURL

    private let accent = Color(red: 0.0, green: 0.74, blue: 0.74)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                profileCard
                preferencesSection
                permissionsSection
                subscriptionSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 96)
        }
        .task {
            await viewModel.refreshSubscriptionStatus()
        }
        .onDisappear {
            viewModel.commitNameDraft()
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $viewModel.showingPlans) {
            SubscriptionPlansSheet()
                .onDisappear {
                    Task {
                        await viewModel.refreshSubscriptionStatus(force: true)
                    }
                }
        }
        .manageSubscriptionsSheet(isPresented: $viewModel.showingManageSubscriptions)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            Text("Your surf setup, tucked in one place.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    private var profileCard: some View {
        SettingsCard {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.16))
                    Image(systemName: "figure.surfing")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Profile")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)

                    TextField("Display name", text: $viewModel.nameDraft)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.commitNameDraft()
                        }
                }
            }
        }
    }

    private var preferencesSection: some View {
        SettingsSection(title: "Surf Preferences", symbol: "water.waves") {
            VStack(spacing: 12) {
                SettingsChoiceGroup(
                    title: "Surfer level",
                    options: UserPreferences.Persona.allCases,
                    selection: viewModel.preferences.persona ?? .intermediate,
                    titleForOption: personaTitle,
                    subtitleForOption: personaSubtitle,
                    action: viewModel.updatePersona
                )

                SettingsSegmentedGroup(
                    title: "Units",
                    options: UserPreferences.Units.allCases,
                    selection: viewModel.preferences.units ?? .imperial,
                    titleForOption: unitsTitle,
                    action: viewModel.updateUnits
                )

                SettingsSegmentedGroup(
                    title: "Wave height",
                    options: UserPreferences.HeightDisplay.allCases,
                    selection: viewModel.preferences.heightDisplay ?? .waveFace,
                    titleForOption: heightDisplayTitle,
                    action: viewModel.updateHeightDisplay
                )
            }
        }
    }

    private var permissionsSection: some View {
        SettingsSection(title: "Permissions", symbol: "checkmark.shield") {
            VStack(spacing: 0) {
                PermissionStatusRow(
                    symbol: "location.fill",
                    title: "Location",
                    state: viewModel.preferences.permissions.location
                )
                SettingsDivider()
                PermissionStatusRow(
                    symbol: "heart.fill",
                    title: "Health",
                    state: viewModel.preferences.permissions.health
                )
                SettingsDivider()
                PermissionStatusRow(
                    symbol: "bell.badge.fill",
                    title: "Notifications",
                    state: viewModel.preferences.permissions.notifications
                )
                SettingsDivider()
                SettingsActionRow(
                    symbol: "gearshape.fill",
                    title: "Open iOS Settings",
                    detail: "System permissions",
                    isBusy: false
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
    }

    private var subscriptionSection: some View {
        SettingsSection(title: "Conatus Pro", symbol: "sparkles") {
            VStack(spacing: 0) {
                SubscriptionStatusRow(
                    isActive: viewModel.hasActiveSubscription,
                    isChecking: viewModel.isCheckingSubscription
                )
                SettingsDivider()
                SettingsActionRow(
                    symbol: "arrow.clockwise",
                    title: "Restore Purchases",
                    detail: viewModel.isRestoringPurchases ? "Checking Apple ID" : "Sync App Store access",
                    isBusy: viewModel.isRestoringPurchases
                ) {
                    Task {
                        await viewModel.restorePurchases()
                    }
                }
                SettingsDivider()
                SettingsActionRow(
                    symbol: "creditcard.fill",
                    title: "Manage Subscription",
                    detail: "Apple subscription settings",
                    isBusy: false
                ) {
                    viewModel.showingManageSubscriptions = true
                }
                SettingsDivider()
                SettingsActionRow(
                    symbol: "rectangle.stack.fill.badge.plus",
                    title: "View Plans",
                    detail: "Monthly and annual options",
                    isBusy: false
                ) {
                    viewModel.showingPlans = true
                }
            }
        }
    }

    private func personaTitle(_ persona: UserPreferences.Persona) -> String {
        switch persona {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    private func personaSubtitle(_ persona: UserPreferences.Persona) -> String {
        switch persona {
        case .beginner: return "Simple reads and friendly windows"
        case .intermediate: return "Reliable forecasts for favorite spots"
        case .advanced: return "Rawer signals and sharper timing"
        }
    }

    private func unitsTitle(_ units: UserPreferences.Units) -> String {
        switch units {
        case .imperial: return "Imperial"
        case .metric: return "Metric"
        }
    }

    private func heightDisplayTitle(_ heightDisplay: UserPreferences.HeightDisplay) -> String {
        switch heightDisplay {
        case .waveFace: return "Wave Face"
        case .swellHeight: return "Swell"
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            SettingsCard {
                content
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
}

private struct SettingsChoiceGroup<Option: Hashable>: View {
    let title: String
    let options: [Option]
    let selection: Option
    let titleForOption: (Option) -> String
    let subtitleForOption: (Option) -> String
    let action: (Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsGroupTitle(title)

            VStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        action(option)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selection == option ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(selection == option ? Color(red: 0.0, green: 0.74, blue: 0.74) : .secondary)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(titleForOption(option))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text(subtitleForOption(option))
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selection == option ? Color(red: 0.0, green: 0.74, blue: 0.74).opacity(0.12) : Color.primary.opacity(0.035))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SettingsSegmentedGroup<Option: Hashable>: View {
    let title: String
    let options: [Option]
    let selection: Option
    let titleForOption: (Option) -> String
    let action: (Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsGroupTitle(title)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        action(option)
                    } label: {
                        Text(titleForOption(option))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(selection == option ? .white : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selection == option ? Color(red: 0.0, green: 0.74, blue: 0.74) : Color.primary.opacity(0.045))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SettingsGroupTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
    }
}

private struct PermissionStatusRow: View {
    let symbol: String
    let title: String
    let state: UserPreferences.GrantState

    var body: some View {
        HStack(spacing: 12) {
            SettingsRowIcon(symbol: symbol, color: statusColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: statusSymbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 10)
    }

    private var statusText: String {
        switch state {
        case .notDetermined: return "Not set"
        case .granted: return "Allowed"
        case .denied: return "Denied"
        case .skipped: return "Skipped"
        }
    }

    private var statusSymbol: String {
        switch state {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined, .skipped: return "minus.circle.fill"
        }
    }

    private var statusColor: Color {
        switch state {
        case .granted: return Color(red: 0.0, green: 0.74, blue: 0.74)
        case .denied: return .red.opacity(0.8)
        case .notDetermined, .skipped: return .secondary
        }
    }
}

private struct SubscriptionStatusRow: View {
    let isActive: Bool
    let isChecking: Bool

    var body: some View {
        HStack(spacing: 12) {
            SettingsRowIcon(
                symbol: isActive ? "sparkles" : "sparkle.magnifyingglass",
                color: isActive ? Color(hex: 0x1F3CFF) : .secondary
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(isActive ? "Pro Active" : "Free Plan")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(isChecking ? "Checking status" : statusDetail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if isChecking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(isActive ? "Active" : "Free")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isActive ? Color(hex: 0x1F3CFF) : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill((isActive ? Color(hex: 0x1F3CFF) : Color.secondary).opacity(0.12))
                    )
            }
        }
        .padding(.vertical, 10)
    }

    private var statusDetail: String {
        isActive ? "Thanks for supporting Conatus" : "Upgrade anytime"
    }
}

private struct SettingsActionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsRowIcon(symbol: symbol, color: Color(red: 0.0, green: 0.74, blue: 0.74))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

private struct SettingsRowIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(color.opacity(0.12))
            )
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 46)
    }
}

private struct SubscriptionPlansSheet: View {
    var body: some View {
        SubscriptionStoreView(productIDs: SubscriptionProductID.all) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1F3CFF))

                Text("Conatus Pro")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))

                Text("AI surf verdicts, multi-spot planning, and deeper session tools.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    SettingsContentView(viewModel: SettingsViewModel())
}
