import Foundation
import StoreKit

public struct CachedProducts: Sendable {
    public let products: [Product]
    public let cachedAt: Date

    public init(products: [Product], cachedAt: Date = Date()) {
        self.products = products
        self.cachedAt = cachedAt
    }

    public func isFresh(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(cachedAt) < ttl
    }
}

public protocol PaywallCache: Sendable {
    func read(_ key: PaywallType) async -> CachedProducts?
    func write(_ key: PaywallType, products: [Product]) async
    func invalidate(_ key: PaywallType?) async
    var ttl: TimeInterval { get }
}
