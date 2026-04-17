import Foundation
import StoreKit
import PaywallKit

/// Stub — thêm `purchases-ios` vào Package.swift dependencies và implement.
///
/// Bridge từ `RevenueCat.Offerings` → StoreKit.Product: `Offering.availablePackages[i].storeProduct.sk2Product`.
/// Lifecycle:
/// - `products(for:mode:)` → gọi `Purchases.shared.offerings()` rồi lọc offering ID theo `PaywallType`.
/// - `refreshEntitlements()` → gọi `Purchases.shared.customerInfo()` → map entitlement active.
/// - `transactionUpdates` → forward từ `Purchases.shared.customerInfoStream`.
/// - `restorePurchases()` → gọi `Purchases.shared.restorePurchases()`.
public final class RevenueCatProductProvider: ProductProvider {
    public let providerName = "RevenueCat"
    public let transactionUpdates: AsyncStream<VerifiedTransaction>
    private let continuation: AsyncStream<VerifiedTransaction>.Continuation

    public init() {
        let (stream, continuation) = AsyncStream<VerifiedTransaction>.makeStream()
        self.transactionUpdates = stream
        self.continuation = continuation
    }

    public func products(for type: PaywallType, mode: ProductMode) async throws -> [Product] {
        throw PaywallError.adapter(
            providerName: providerName,
            message: "RevenueCatProductProvider chưa implement — thêm dependency purchases-ios và hoàn thiện."
        )
    }

    public func refreshEntitlements() async throws -> Set<Entitlement> {
        throw PaywallError.adapter(
            providerName: providerName,
            message: "refreshEntitlements chưa implement."
        )
    }

    public func restorePurchases() async throws -> Set<Entitlement> {
        throw PaywallError.adapter(
            providerName: providerName,
            message: "restorePurchases chưa implement."
        )
    }
}
