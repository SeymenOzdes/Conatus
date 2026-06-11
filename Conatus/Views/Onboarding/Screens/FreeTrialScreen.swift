//
//  FreeTrialScreen.swift
//  Conatus
//
//  Created by Seymen Özdeş on 10.05.2026.
//

import StoreKit
import SwiftUI

struct FreeTrialScreen: View {
    @Bindable var state: OnboardingState
    @Environment(\.openURL) private var openURL

    @State private var products: [Product] = []
    @State private var selectedProductID: Product.ID?
    @State private var isLoadingProducts = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var alert: StoreAlert?

    private let subscriptionStore = SubscriptionStore()
    private let reminderLeadDays = 2

    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://conatus.app/privacy")!

    private let accent = Color(hex: 0x1F3CFF)

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headline
                    planSelector
                    timeline
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onboardingBackground()
        .preferredColorScheme(.dark)
        .task {
            await loadProducts()
        }
        .alert(item: $alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        GeometryReader { proxy in
            let barWidth = (proxy.size.width - 32) * 0.75
            HStack(spacing: 0) {
                Button(action: { state.back() }) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Spacer(minLength: 0)

                OnboardingProgressBar(total: state.totalSteps, current: state.currentStep)
                    .frame(width: barWidth)

                Spacer(minLength: 0)

                Color.clear.frame(width: 36, height: 36)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .frame(height: 56)
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try Conatus Pro free for \(trialLengthText).")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitleText)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plans

    @ViewBuilder
    private var planSelector: some View {
        if isLoadingProducts && products.isEmpty {
            PlanLoadingCard()
        } else if products.isEmpty {
            PlanErrorCard(action: {
                Task { await loadProducts(force: true) }
            })
        } else {
            VStack(spacing: 12) {
                ForEach(products, id: \.id) { product in
                    SubscriptionPlanCard(
                        product: product,
                        isSelected: product.id == selectedProductID,
                        onSelect: { selectedProductID = product.id }
                    )
                }
            }
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrialTimelineRow(
                title: "Today",
                detail: "Unlock Pro features: AI surf verdicts, multi-spot best-window, and session logging.",
                accent: accent,
                style: .leading
            )

            TrialTimelineRow(
                title: reminderTitle,
                detail: "We'll remind you \(reminderLeadDays) days before your trial ends.",
                accent: accent,
                style: .middle
            )

            TrialTimelineRow(
                title: "After \(trialLengthText)",
                detail: "Your selected plan begins. Cancel anytime in Settings at least 24 hours before.",
                accent: accent,
                style: .trailing
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            OnboardingPrimaryButton(
                title: primaryButtonTitle,
                isEnabled: selectedProduct != nil && !isBusy,
                action: {
                    Task { await purchaseSelectedProduct() }
                }
            )

            HStack(spacing: 24) {
                Button(restoreButtonTitle) {
                    Task { await restorePurchases() }
                }
                .disabled(isBusy)

                Button("Maybe later") {
                    state.complete()
                }
                .disabled(isBusy)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(isBusy ? 0.35 : 0.7))

            legalFooter
        }
        .padding(.bottom, 16)
    }

    private var legalFooter: some View {
        HStack(spacing: 4) {
            Button("Terms of Use") { openURL(termsURL) }
            Text("/")
            Button("Privacy Policy") { openURL(privacyURL) }
        }
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.55))
        .padding(.top, 4)
    }

    // MARK: - State

    private var selectedProduct: Product? {
        products.first { $0.id == selectedProductID } ?? products.first
    }

    private var selectedSubscription: Product.SubscriptionInfo? {
        selectedProduct?.subscription
    }

    private var selectedTrialPeriod: Product.SubscriptionPeriod? {
        selectedSubscription?.introductoryOffer?.freeTrialPeriod
    }

    private var trialLengthText: String {
        selectedTrialPeriod?.displayText ?? "your trial"
    }

    private var subtitleText: String {
        guard let selectedProduct else {
            return isLoadingProducts ? "Loading current App Store pricing..." : "Choose a plan once App Store pricing loads."
        }

        let period = selectedProduct.subscription?.subscriptionPeriod.billingText ?? "subscription"
        return "Then \(selectedProduct.displayPrice)/\(period). Cancel anytime."
    }

    private var reminderTitle: String {
        guard let selectedTrialPeriod,
              selectedTrialPeriod.unit == .day,
              selectedTrialPeriod.value > reminderLeadDays else {
            return "Before your trial ends"
        }

        return "In \(selectedTrialPeriod.value - reminderLeadDays) days"
    }

    private var primaryButtonTitle: String {
        if isLoadingProducts {
            return "Loading Plans..."
        }
        if isPurchasing {
            return "Starting Trial..."
        }
        return "Start \(trialLengthText.capitalized) Free Trial"
    }

    private var restoreButtonTitle: String {
        isRestoring ? "Restoring..." : "Restore Purchases"
    }

    private var isBusy: Bool {
        isLoadingProducts || isPurchasing || isRestoring
    }

    // MARK: - Actions

    private func loadProducts(force: Bool = false) async {
        guard force || products.isEmpty else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loadedProducts = try await subscriptionStore.loadProducts()
            products = loadedProducts
            selectedProductID = loadedProducts.first?.id
        } catch {
            alert = StoreAlert(
                title: "Plans unavailable",
                message: error.localizedDescription
            )
        }
    }

    private func purchaseSelectedProduct() async {
        guard let selectedProduct else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await subscriptionStore.purchase(selectedProduct)
            state.complete()
        } catch {
            alert = StoreAlert(
                title: "Purchase unavailable",
                message: error.localizedDescription
            )
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await subscriptionStore.restorePurchases()
            state.complete()
        } catch {
            alert = StoreAlert(
                title: "No purchases to restore",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Plan cards

private struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void

    private let accent = Color(hex: 0x1F3CFF)

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : .white.opacity(0.5))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        if product.id == SubscriptionProductID.annual {
                            Text("Best value")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.white))
                        }
                    }

                    Text(detailText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if let period = product.subscription?.subscriptionPeriod.billingText {
                        Text("/\(period)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.16 : 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(isSelected ? 0.34 : 0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        let trial = product.subscription?.introductoryOffer?.freeTrialPeriod?.displayText
        let period = product.subscription?.subscriptionPeriod.billingText

        switch (trial, period) {
        case let (.some(trial), .some(period)):
            return "\(trial.capitalized) free, then billed every \(period)."
        case let (.some(trial), .none):
            return "\(trial.capitalized) free trial."
        case let (.none, .some(period)):
            return "Billed every \(period)."
        case (.none, .none):
            return "Conatus Pro subscription."
        }
    }
}

private struct PlanLoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            Text("Loading App Store plans...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.10))
        )
    }
}

private struct PlanErrorCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plans could not be loaded.")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Button("Try Again", action: action)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: 0x1F3CFF))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(.white))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.10))
        )
    }
}

// MARK: - Timeline row

private struct TrialTimelineRow: View {
    enum Style { case leading, middle, trailing }

    let title: String
    let detail: String
    let accent: Color
    let style: Style

    private let dotSize: CGFloat = 9.3
    private let railWidth: CGFloat = 7
    private let railColumnWidth: CGFloat = 14

    var body: some View {
        HStack(alignment: .top, spacing: 37) {
            railColumn
                .frame(width: railColumnWidth)

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 19.5, weight: .semibold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, style == .trailing ? 0 : 28)
        }
        .accessibilityElement(children: .combine)
    }

    private var railColumn: some View {
        VStack(spacing: 9) {
            Circle()
                .fill(accent)
                .frame(width: dotSize, height: dotSize)

            switch style {
            case .leading, .middle:
                Rectangle()
                    .fill(accent)
                    .frame(width: railWidth)
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 9)
            case .trailing:
                Image(systemName: "arrow.down")
                    .font(.system(size: 49, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }
}

// MARK: - Helpers

private struct StoreAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private extension Product.SubscriptionOffer {
    var freeTrialPeriod: Product.SubscriptionPeriod? {
        paymentMode == .freeTrial ? period : nil
    }
}

private extension Product.SubscriptionPeriod {
    var displayText: String {
        "\(value) \(unit.displayName(count: value))"
    }

    var billingText: String {
        value == 1 ? unit.displayName(count: 1) : displayText
    }
}

private extension Product.SubscriptionPeriod.Unit {
    func displayName(count: Int) -> String {
        let singular: String
        switch self {
        case .day:
            singular = "day"
        case .week:
            singular = "week"
        case .month:
            singular = "month"
        case .year:
            singular = "year"
        @unknown default:
            singular = "period"
        }

        return count == 1 ? singular : "\(singular)s"
    }
}
