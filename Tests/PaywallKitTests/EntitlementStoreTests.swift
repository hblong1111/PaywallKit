import Testing
import Foundation
@testable import PaywallKit

@Suite("EntitlementStore")
struct EntitlementStoreTests {
    @Test @MainActor
    func initialState() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        #expect(store.active.isEmpty)
        #expect(!store.isSubscribed)
    }

    @Test @MainActor
    func setAndHas() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        let pro = Entitlement(id: "pro", productID: "com.app.pro", source: .purchase)
        store.set([pro])
        #expect(store.has("pro"))
        #expect(store.isSubscribed)
    }

    @Test @MainActor
    func grantEphemeralIsActiveUntilExpiry() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        store.grantEphemeral("pro", until: Date().addingTimeInterval(60))
        #expect(store.has("pro"))
        #expect(!store.isSubscribed)  // ephemeral không tính là subscribed
        #expect(store.hasAnyActive)
    }

    @Test @MainActor
    func ephemeralExpiredNotActive() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        let ent = Entitlement(
            id: "pro",
            expiresAt: Date().addingTimeInterval(-10),
            isEphemeral: true,
            source: .rewardAd
        )
        store.upsert(ent)
        #expect(!store.has("pro"))
    }

    @Test @MainActor
    func setPreservesEphemeral() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        store.grantEphemeral("bonus", until: Date().addingTimeInterval(60))
        store.set([Entitlement(id: "pro", source: .purchase)])
        #expect(store.has("pro"))
        #expect(store.has("bonus"))
    }

    @Test @MainActor
    func revokeRemovesNonEphemeralOnly() {
        let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
        store.set([Entitlement(id: "pro", source: .purchase)])
        store.revoke("pro")
        #expect(!store.has("pro"))
    }

    @Test @MainActor
    func persistenceRoundTrip() throws {
        let persistence = InMemoryEntitlementPersistence()
        do {
            let store = EntitlementStore(persistence: persistence)
            store.set([Entitlement(id: "pro", productID: "sku", source: .purchase)])
        }
        let reloaded = EntitlementStore(persistence: persistence)
        #expect(reloaded.has("pro"))
    }
}
