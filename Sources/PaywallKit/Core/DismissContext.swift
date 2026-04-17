import Foundation

public struct DismissContext: Sendable {
    public let paywallType: PaywallType
    public let reason: DismissReason
    public let didPurchase: Bool
    public let purchasedProductID: String?

    public init(
        paywallType: PaywallType,
        reason: DismissReason,
        didPurchase: Bool,
        purchasedProductID: String? = nil
    ) {
        self.paywallType = paywallType
        self.reason = reason
        self.didPurchase = didPurchase
        self.purchasedProductID = purchasedProductID
    }
}

public enum DismissReason: Sendable, Equatable {
    case user
    case programmatic
    case afterPurchase
    case interceptor(String)
    case queueEvicted
}
