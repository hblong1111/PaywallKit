import Foundation
import StoreKit
import PaywallKit

/// Stub — thêm `Superwall-iOS` vào Package.swift dependencies và implement.
///
/// Bridge:
/// - `products(for:mode:)` → `Superwall.shared.getPresentationResult(for: placementID)` hoặc API placement tương đương.
/// - `refreshEntitlements()` → `Superwall.shared.subscriptionStatus` hoặc entitlement API.
/// - `transactionUpdates` → `Superwall.shared.delegate` → forward qua stream.
/// - `restorePurchases()` → `Superwall.shared.restorePurchases()`.
public final class SuperwallProductProvider: ProductProvider {
    public let providerName = "Superwall"
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
            message: "SuperwallProductProvider chưa implement — thêm dependency Superwall-iOS và hoàn thiện."
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
