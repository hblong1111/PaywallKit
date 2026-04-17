import Foundation
import StoreKit

public protocol ProductProvider: Sendable {
    /// Fetch danh sách product cho 1 paywall type.
    func products(for type: PaywallType, mode: ProductMode) async throws -> [Product]

    /// Đồng bộ entitlement hiện tại với source of truth (StoreKit / RevenueCat / Superwall).
    func refreshEntitlements() async throws -> Set<Entitlement>

    /// Stream transaction update (Transaction.updates với StoreKit 2, hoặc tương đương ở adapter).
    var transactionUpdates: AsyncStream<VerifiedTransaction> { get }

    /// Restore purchase — forward xuống backend tương ứng.
    func restorePurchases() async throws -> Set<Entitlement>

    /// Tên adapter, dùng trong PaywallError.adapter và logging.
    var providerName: String { get }
}
