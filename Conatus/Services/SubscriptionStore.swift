//
//  SubscriptionStore.swift
//  Conatus
//
//  Created by Codex on 11.06.2026.
//

import Foundation
import StoreKit

enum SubscriptionProductID {
    static let monthly = "conatus.pro.monthly"
    static let annual = "conatus.pro.annual"
    static let all = [monthly, annual]
}

enum SubscriptionStoreError: LocalizedError {
    case productsUnavailable
    case unverifiedTransaction
    case pending
    case cancelled
    case noActiveSubscription

    var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            "We couldn't load Conatus Pro plans. Please try again."
        case .unverifiedTransaction:
            "We couldn't verify this purchase. Please try again."
        case .pending:
            "Your purchase is pending approval."
        case .cancelled:
            "Purchase cancelled."
        case .noActiveSubscription:
            "We couldn't find an active Conatus subscription on this Apple ID."
        }
    }
}

struct SubscriptionStore {
    func loadProducts() async throws -> [Product] {
        let products = try await Product.products(for: SubscriptionProductID.all)
            .filter { SubscriptionProductID.all.contains($0.id) }
            .sorted { $0.price < $1.price }

        guard !products.isEmpty else {
            throw SubscriptionStoreError.productsUnavailable
        }

        return products
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            let transaction = try verifiedTransaction(from: verification)
            await transaction.finish()
        case .pending:
            throw SubscriptionStoreError.pending
        case .userCancelled:
            throw SubscriptionStoreError.cancelled
        @unknown default:
            throw SubscriptionStoreError.unverifiedTransaction
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()

        guard await hasActiveSubscription() else {
            throw SubscriptionStoreError.noActiveSubscription
        }
    }

    func hasActiveSubscription() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement,
                  SubscriptionProductID.all.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true else {
                continue
            }

            return true
        }

        return false
    }

    private func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case let .verified(transaction):
            transaction
        case .unverified:
            throw SubscriptionStoreError.unverifiedTransaction
        }
    }
}
