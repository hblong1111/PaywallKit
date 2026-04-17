import Testing
import Foundation
@testable import PaywallKit

@Suite("InMemoryPaywallCache")
struct InMemoryPaywallCacheTests {
    @Test
    func readMissReturnsNil() async {
        let cache = InMemoryPaywallCache(ttl: 60)
        let result = await cache.read(.init("onboarding"))
        #expect(result == nil)
    }

    @Test
    func invalidateSpecific() async {
        let cache = InMemoryPaywallCache(ttl: 60)
        await cache.write(.init("a"), products: [])
        await cache.write(.init("b"), products: [])
        await cache.invalidate(.init("a"))
        let a = await cache.read(.init("a"))
        let b = await cache.read(.init("b"))
        #expect(a == nil)
        #expect(b != nil)
    }

    @Test
    func invalidateAll() async {
        let cache = InMemoryPaywallCache(ttl: 60)
        await cache.write(.init("a"), products: [])
        await cache.write(.init("b"), products: [])
        await cache.invalidate(nil)
        let a = await cache.read(.init("a"))
        let b = await cache.read(.init("b"))
        #expect(a == nil)
        #expect(b == nil)
    }

    @Test
    func freshnessCheck() {
        let fresh = CachedProducts(products: [], cachedAt: Date())
        let stale = CachedProducts(products: [], cachedAt: Date().addingTimeInterval(-120))
        #expect(fresh.isFresh(ttl: 60))
        #expect(!stale.isFresh(ttl: 60))
    }
}
