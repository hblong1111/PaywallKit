# Testing

Mock provider, StoreKit config file, snapshot test, và preview không cần StoreKit thật.

## Overview

Test PaywallKit ở 3 mức:

1. **Unit test** — logic thuần (strategy, cache, entitlement store). Chạy nhanh, không cần StoreKit.
2. **Integration test** — provider + purchase flow. Cần `SKTestSession` + `.storekit` file.
3. **Preview** — view render đúng state. Dùng `PaywallManager.preview()`.

## 1. Unit test

### Test selection strategy

```swift
import Testing
@testable import PaywallKit

@Test
func cheapestStrategy() {
    let products = makeMockProducts(prices: [9.99, 4.99, 14.99])
    let picked = SelectionStrategy.cheapest.pick(from: products)
    #expect(picked?.price == 4.99)
}
```

Product là type Apple không init được thuần — cần `SKTestSession`. Với unit test không chạm StoreKit, chỉ test `.custom` strategy:

```swift
@Test
func customStrategy() {
    let strategy = SelectionStrategy.custom { products in
        products.first
    }
    // chỉ test closure logic, không cần Product thật
}
```

### Test EntitlementStore (không cần StoreKit)

```swift
@Test @MainActor
func grantEphemeralExpires() async throws {
    let store = EntitlementStore(persistence: InMemoryEntitlementPersistence())
    store.grantEphemeral("pro", until: Date().addingTimeInterval(-1))
    #expect(!store.has("pro"))  // đã expired
}
```

### Test interceptor chain

```swift
@Test @MainActor
func interceptorBlocksPresent() async throws {
    struct Blocker: PaywallInterceptor {
        func willPresent(type: PaywallType) async throws {
            throw PaywallError.interceptorBlocked(reason: "test")
        }
    }

    let manager = PaywallManager(
        provider: MockProductProvider(),
        interceptors: [Blocker()]
    )
    manager.register(.onboarding, config: .init(productMode: .single(productID: "sku")))

    await #expect(throws: PaywallError.self) {
        try await manager.present(.onboarding)
    }
}
```

## 2. Integration test với SKTestSession

Tạo `.storekit` config file trong project (File > New > StoreKit Configuration File), chứa product và subscription giả.

```swift
import StoreKitTest

@Test @MainActor
func purchaseFlow() async throws {
    let session = try SKTestSession(configurationFileNamed: "Paywall")
    session.resetToDefaultState()
    session.clearTransactions()

    let manager = PaywallManager(
        provider: StoreKitProductProvider(productIDMap: [
            .onboarding: ["com.test.monthly"]
        ]),
        entitlementPersistence: InMemoryEntitlementPersistence()
    )
    manager.register(.onboarding, config: .init(productMode: .single(productID: "com.test.monthly")))

    try await manager.present(.onboarding)
    #expect(manager.selection.selected?.id == "com.test.monthly")

    try await manager.purchaseSelected()
    #expect(manager.entitlements.has("com.test.monthly"))
}
```

`SKTestSession` cho phép simulate: cancel, ask-to-buy, refund, interruption.

## 3. MockProductProvider

Viết provider giả để test business logic mà không chạm StoreKit:

```swift
public final class MockProductProvider: ProductProvider {
    public let providerName = "Mock"
    public let transactionUpdates: AsyncStream<VerifiedTransaction>

    private let continuation: AsyncStream<VerifiedTransaction>.Continuation
    public var fetchedProducts: [Product] = []
    public var mockEntitlements: Set<Entitlement> = []
    public var errorToThrow: PaywallError?

    public init() {
        let (stream, cont) = AsyncStream<VerifiedTransaction>.makeStream()
        self.transactionUpdates = stream
        self.continuation = cont
    }

    public func products(for type: PaywallType, mode: ProductMode) async throws -> [Product] {
        if let errorToThrow { throw errorToThrow }
        return fetchedProducts
    }

    public func refreshEntitlements() async throws -> Set<Entitlement> {
        mockEntitlements
    }

    public func restorePurchases() async throws -> Set<Entitlement> {
        mockEntitlements
    }

    public func simulateBackgroundTransaction(_ transaction: VerifiedTransaction) {
        continuation.yield(transaction)
    }
}
```

## 4. Preview

Thêm static factory vào `PaywallManager` extension trong app (hoặc lib version tương lai):

```swift
#if DEBUG
extension PaywallManager {
    static func preview(entitlements: Set<Entitlement> = []) -> PaywallManager {
        let provider = MockProductProvider()
        let manager = PaywallManager(
            provider: provider,
            entitlementPersistence: InMemoryEntitlementPersistence()
        )
        manager.entitlements.set(entitlements)
        return manager
    }
}
#endif

#Preview("Onboarding") {
    OnboardingPaywallView()
        .environment(PaywallManager.preview())
}

#Preview("Onboarding - Subscribed") {
    OnboardingPaywallView()
        .environment(PaywallManager.preview(entitlements: [
            Entitlement(id: "pro", source: .purchase)
        ]))
}
```

## 5. Snapshot test UI

Với `swift-snapshot-testing`:

```swift
@Test @MainActor
func onboardingPaywallSnapshot() {
    let view = OnboardingPaywallView()
        .environment(PaywallManager.preview())

    assertSnapshot(matching: view, as: .image(on: .iPhone15))
}
```

Lưu ý Product trong preview là giả — price sẽ render placeholder. Nếu muốn snapshot đúng price, dùng `SKTestSession` + storekit config cho preview.

## Tips

- **Isolate Keychain trong test:** dùng `InMemoryEntitlementPersistence()` thay vì keychain thật — test parallel không bị race.
- **Clear `Transaction.updates` state giữa các test:** `session.clearTransactions()`.
- **Test timeout:** interceptor timeout = 5s. Với test, override qua `PurchaseOptions(interceptorTimeout: 0.1)` để test không chậm.
- **Test event stream:** dùng `AsyncStream.prefix(n)` để collect n event đầu, không phải đợi stream close.

```swift
@Test @MainActor
func eventsEmittedOnPresent() async throws {
    let manager = PaywallManager(provider: MockProductProvider())
    manager.register(.onboarding, config: .init(productMode: .single(productID: "sku")))

    Task { try? await manager.present(.onboarding) }

    var collected: [PaywallEvent] = []
    for await event in manager.events.prefix(2) {
        collected.append(event)
    }
    #expect(collected.count == 2)
}
```
