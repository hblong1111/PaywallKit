import Foundation
import StoreKit

public actor InMemoryPaywallCache: PaywallCache {
    public let ttl: TimeInterval
    private var storage: [PaywallType: CachedProducts] = [:]

    public init(ttl: TimeInterval = 3600) {
        self.ttl = ttl
    }

    public func read(_ key: PaywallType) async -> CachedProducts? {
        guard let entry = storage[key], entry.isFresh(ttl: ttl) else { return nil }
        return entry
    }

    public func write(_ key: PaywallType, products: [Product]) async {
        storage[key] = CachedProducts(products: products, cachedAt: Date())
    }

    public func invalidate(_ key: PaywallType?) async {
        if let key {
            storage.removeValue(forKey: key)
        } else {
            storage.removeAll()
        }
    }
}
