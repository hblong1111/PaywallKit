# PaywallKit — Design Document

Tài liệu thiết kế cho PaywallKit: thư viện Swift hỗ trợ show & quản lý paywall cho iOS app, cho phép app tự custom UI nhưng gom toàn bộ logic chung (fetch product, cache, purchase flow, event, entitlement) vào một chỗ.

**Status:** Draft — chưa implement. Chốt API ở đây trước, rồi mới viết Swift.

---

## 1. Mục tiêu

- **Một nguồn sự thật** cho trạng thái paywall & entitlement trong app.
- **Cho app tự vẽ UI** nhưng *không* phải tự wire lại: purchase flow, dismiss lifecycle, event forwarding, cache product, đồng bộ entitlement.
- **Linh hoạt shape paywall** — 1 product / nhiều product, default selection theo chiến lược, popup / sheet / fullscreen / custom transition, per-paywall-type.
- **Custom action bên trong paywall** — reward ads button, redeem code, contact support… qua adapter do app cung cấp; lib không phụ thuộc AdMob/AppLovin/…
- **Hỗ trợ 3 backend** cho product/paywall config: StoreKit 2 (native), RevenueCat, Superwall — chung một interface.
- **Mở rộng được** qua interceptor (ads trước dismiss, confirm dialog, remote gating) và analytics observer (Firebase, Mixpanel, AppsFlyer).
- **Observable-first** — UI SwiftUI bind trực tiếp vào state, không cần Combine / NotificationCenter.

### Nguyên tắc thiết kế

> **Gom những gì chung ở mọi app, chỉ expose những gì đặc thù theo UI của từng app.**

Mọi quyết định API đều đối chiếu với nguyên tắc này: nếu 2+ app sẽ viết cùng một đoạn code, đoạn đó thuộc về lib.

---

## 2. Non-goals

- **Không ship UI paywall mặc định.** Lib không có template đẹp sẵn — app tự vẽ.
- **Không làm server-side receipt validation.** App/backend lo phần đó; lib chỉ cung cấp transaction & JWS.
- **Không làm A/B testing / remote config engine.** Giao cho Superwall/RevenueCat/Firebase Remote Config; lib chỉ consume.
- **Không support UIKit như first-class** — sẽ dùng được qua `UIHostingController`, nhưng API thiết kế cho SwiftUI + `@Observable`.
- **Không support iOS < 17** (cần `@Observable`, StoreKit 2 APIs mới).

---

## 3. Ràng buộc kỹ thuật

- Swift tools `6.2`, Swift 6 strict concurrency.
- iOS 17+ (macro `@Observable`, `Observable` macro yêu cầu 17).
- StoreKit 2 (`Product`, `Transaction`, `Transaction.updates`, JWS verification).
- async/await; không dùng Combine.
- RevenueCat & Superwall là **optional dependency** qua package traits (hoặc separate target) — app không dùng không phải kéo về.
- `@MainActor` cho toàn bộ state UI; purchase/network chạy trên background, hop về main khi update state.

---

## 4. Kiến trúc tổng quan

```
┌────────────────────────────────────────────────────────────────┐
│                         App layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │Onboarding    │  │Settings      │  │Feature-gated screens │  │
│  │ Paywall View │  │ Paywall View │  │ (read entitlement)   │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                     │              │
└─────────┼─────────────────┼─────────────────────┼──────────────┘
          │                 │                     │
┌─────────▼─────────────────▼─────────────────────▼──────────────┐
│                    PaywallKitUI (optional)                      │
│  PaywallRegistry · .paywallPresenter() · PaywallBuyButton ·     │
│  PaywallRestoreButton · PaywallCloseButton · Preview helpers    │
└─────────────────────────────┬───────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                       PaywallKit (core)                         │
│                                                                 │
│   ┌─────────────────── PaywallManager (@Observable) ────────┐   │
│   │  presentedType · isLoading · lastError · selection      │   │
│   └─────┬─────────────┬──────────────┬──────────────┬───────┘   │
│         │             │              │              │           │
│  ┌──────▼───┐  ┌──────▼──────┐  ┌───▼────────┐  ┌──▼────────┐   │
│  │Product   │  │Purchase     │  │Entitlement │  │Paywall    │   │
│  │Provider  │  │Coordinator  │  │Store       │  │Cache      │   │
│  │(protocol)│  │             │  │(@Observable│  │           │   │
│  └────┬─────┘  └─────┬───────┘  └────────────┘  └───────────┘   │
│       │              │                                          │
│  ┌────┴─────┐        │    ┌──────────────────────────────┐      │
│  │StoreKit  │        │    │ Interceptor chain            │      │
│  │RevenueCat│        │◄───┤ (willDismiss / willPurchase) │      │
│  │Superwall │        │    └──────────────────────────────┘      │
│  └──────────┘        │    ┌──────────────────────────────┐      │
│                      └───►│ AnalyticsObserver (multi)    │      │
│                           └──────────────────────────────┘      │
│                                                                 │
│   AsyncStream<PaywallEvent>  →  app có thể subscribe tự do      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Core modules

### 5.1 `PaywallManager` — entry point

`@Observable`, `@MainActor`. Singleton-friendly (nhưng không bắt buộc singleton; app có thể scope theo feature).

**Trách nhiệm:**
- Giữ state toàn cục của paywall hiện tại (`presentedType`, `isLoading`, `lastError`).
- Route call sang `ProductProvider` / `PurchaseCoordinator` / `EntitlementStore`.
- Chạy interceptor chain quanh lifecycle event.
- Multicast event ra `AsyncStream` và `AnalyticsObserver`.

**API phác thảo:**
```swift
@MainActor @Observable
public final class PaywallManager {
    public private(set) var presentedType: PaywallType?
    public private(set) var isLoading: Bool = false
    public private(set) var lastError: PaywallError?
    public let selection: PaywallSelection
    public let entitlements: EntitlementStore

    public init(
        provider: any ProductProvider,
        cache: PaywallCache = .inMemory(ttl: 3600),
        interceptors: [any PaywallInterceptor] = [],
        analytics: [any PaywallAnalyticsObserver] = []
    )

    public func present(_ type: PaywallType) async throws
    public func dismiss() async
    public func purchase(_ product: Product) async throws
    public func restore() async throws

    public var events: AsyncStream<PaywallEvent> { get }
}
```

### 5.2 `ProductProvider` — adapter protocol

```swift
public protocol ProductProvider: Sendable {
    func products(for type: PaywallType) async throws -> [Product]
    func refreshEntitlements() async throws -> Set<Entitlement>
    var transactionUpdates: AsyncStream<VerifiedTransaction> { get }
}
```

**Implementation cung cấp sẵn:**
- `StoreKitProductProvider` — native, default.
- `RevenueCatProductProvider` — trong target `PaywallKitRevenueCat` (optional).
- `SuperwallProductProvider` — trong target `PaywallKitSuperwall` (optional).

App chọn 1 khi init `PaywallManager`. Switch backend = thay 1 dòng.

### 5.3 `PurchaseCoordinator`

Internal. Chịu trách nhiệm:
- Gọi `Product.purchase()` (StoreKit 2) hoặc forward qua adapter.
- Verify JWS, emit `VerifiedTransaction`.
- Finish transaction sau khi app xác nhận delivery (tùy chọn 2-phase).
- Handle `.userCancelled`, `.pending`, network error → map sang `PaywallError`.
- Chạy `interceptor.willPurchase()` trước, emit event sau.

### 5.4 `EntitlementStore` — trạng thái đã mua

`@Observable`, `@MainActor`.

```swift
@MainActor @Observable
public final class EntitlementStore {
    public private(set) var active: Set<Entitlement>
    public var isSubscribed: Bool { !active.isEmpty }
    public func has(_ id: Entitlement.ID) -> Bool

    /// Cấp entitlement tạm thời (ví dụ sau reward ads). Auto-revoke khi đến hạn.
    public func grantEphemeral(_ id: Entitlement.ID, until: Date) async

    // internal: subscribe Transaction.updates, persist snapshot vào Keychain
    // để cold-launch không phải đợi StoreKit load.
    // Ephemeral entitlement KHÔNG persist — mất khi kill app (by design).
}
```

App gate feature bằng cách đọc `entitlements.has(.pro)` trực tiếp trong SwiftUI view.

### 5.5 `PaywallSelection` — "giỏ hàng"

`@Observable`, `@MainActor`. Quản lý product nào đang được chọn trong paywall hiện tại. Phủ cả case single-product lẫn multi-product — single chỉ là multi với 1 item + selection luôn là item đó.

```swift
@MainActor @Observable
public final class PaywallSelection {
    public private(set) var available: [Product] = []
    public var selected: Product?
    public var selectedOffer: Product.SubscriptionOffer?

    public var isSingleProduct: Bool { available.count == 1 }
    public var strategy: SelectionStrategy = .firstAvailable
}

public enum SelectionStrategy: Sendable {
    case firstAvailable               // theo thứ tự trả về từ provider
    case cheapest                     // giá thấp nhất
    case mostExpensive                // thường đẩy annual trước
    case byID(String)                 // ép cứng 1 product ID
    case longestDuration              // thường lifetime > yearly > monthly
    case custom(@Sendable ([Product]) -> Product?)
}
```

Khi `available` được set (sau khi fetch), `selected` được chọn theo `strategy`. App vẫn override được bằng cách gán `selected` trực tiếp.

UI custom của app chỉ cần binding `selection.selected` vào button/radio. Nếu `isSingleProduct == true`, app có thể ẩn phần chọn và chỉ hiện nút mua.

### 5.6 `PaywallCache`

```swift
public protocol PaywallCache: Sendable {
    func read(_ key: PaywallType) async -> CachedProducts?
    func write(_ key: PaywallType, products: [Product]) async
    func invalidate(_ key: PaywallType?) async
}
```

Cung cấp sẵn:
- `InMemoryPaywallCache(ttl:)` — default.
- `FilePaywallCache(url:ttl:)` — persistent, cho cold-launch nhanh (hiện product ngay, refresh nền).

Strategy: **stale-while-revalidate** — present paywall với data cache, đồng thời fire request nền; nếu network trả khác thì update.

### 5.7 `PaywallInterceptor` — hook chặn lifecycle

```swift
public protocol PaywallInterceptor: Sendable {
    func willPresent(type: PaywallType) async throws
    func willPurchase(product: Product) async throws
    func willDismiss(context: DismissContext) async
}
```

**Chain semantics:**
- Chạy **tuần tự** theo thứ tự đăng ký.
- `throws` trong `willPresent`/`willPurchase` → hủy action, emit `.cancelled(reason:)` event.
- `willDismiss` không throw — dùng cho side effect (ads, animation).

**Use case điển hình:**
```swift
final class AdInterceptor: PaywallInterceptor {
    func willDismiss(context: DismissContext) async {
        guard !context.didPurchase else { return }
        await InterstitialAd.shared.showIfReady()
    }
    // willPresent/willPurchase: default (no-op)
}
```

### 5.8 `PaywallAnalyticsObserver` — tracking multi-cast

```swift
public protocol PaywallAnalyticsObserver: Sendable {
    func observe(_ event: PaywallEvent) async
}
```

Khác event stream: multi-subscriber, fire-and-forget, error isolated (1 observer crash không ảnh hưởng observer khác). App cắm nhiều observer song song: Firebase + Mixpanel + AppsFlyer + internal logger.

### 5.9 `PaywallConfiguration` — khai báo shape cho từng paywall type

Mỗi `PaywallType` gắn với 1 `PaywallConfiguration` tĩnh (khai báo 1 lần khi register). Gom mọi quyết định "paywall này trông/hành xử thế nào" vào 1 struct, thay vì rải rác prop khắp manager.

```swift
public struct PaywallConfiguration: Sendable {
    public let productMode: ProductMode
    public let presentation: PresentationStyle
    public let closeButton: CloseButtonBehavior
    public let rewardAd: RewardAdBehavior
    public let allowsQueue: Bool         // cho phép chờ paywall khác dismiss
}

public enum ProductMode: Sendable {
    case single(productID: String)
    case multi(strategy: SelectionStrategy)
}

public enum PresentationStyle: Sendable {
    case sheet(detents: Set<PresentationDetent> = [.large])
    case fullScreenCover
    case popup(backdrop: BackdropStyle = .dim(0.5))   // center card, không full screen
    case custom(@MainActor (AnyView, Binding<Bool>) -> AnyView)
}

public enum CloseButtonBehavior: Sendable {
    case alwaysVisible
    case hidden                      // paywall ép buộc (onboarding bắt mua)
    case visibleAfter(TimeInterval)  // delay ví dụ 3s chống misclick
}

public enum RewardAdBehavior: Sendable {
    case disabled
    case enabled(outcome: RewardOutcomeAction)
}

public enum RewardOutcomeAction: Sendable {
    /// Cấp entitlement tạm thời sau reward ads thành công.
    case grantEphemeral(id: Entitlement.ID, duration: TimeInterval)
    /// Đổi selection sang product rẻ hơn / có discount.
    case switchSelection(toProductID: String)
    /// App tự xử lý — closure nhận kết quả reward, trả về side effect.
    case custom(@MainActor @Sendable (RewardOutcome, PaywallManager) async -> Void)
}
```

**Ví dụ khai báo ở app:**
```swift
registry.register(
    .onboarding,
    config: .init(
        productMode: .multi(strategy: .mostExpensive),  // đẩy yearly
        presentation: .fullScreenCover,
        closeButton: .visibleAfter(3),
        rewardAd: .enabled(outcome: .grantEphemeral(id: .pro, duration: 300)),
        allowsQueue: false
    )
) { OnboardingPaywallView() }

registry.register(
    .featureGate,
    config: .init(
        productMode: .single(productID: "com.app.pro.yearly"),
        presentation: .popup(),
        closeButton: .alwaysVisible,
        rewardAd: .disabled,
        allowsQueue: true
    )
) { FeatureGatePaywallView() }
```

### 5.10 `RewardAdProvider` — adapter reward ads

Lib **không** phụ thuộc AdMob / AppLovin / IronSource. App cung cấp adapter mỏng:

```swift
public protocol RewardAdProvider: Sendable {
    func isReady() async -> Bool
    func show() async throws -> RewardOutcome
}

public struct RewardOutcome: Sendable {
    public let earned: Bool
    public let rewardType: String?
    public let rewardAmount: Double?
}
```

App inject vào `PaywallManager` lúc init:
```swift
PaywallManager(
    provider: StoreKitProductProvider(...),
    rewardAdProvider: MyAdMobRewardAdapter()   // optional
)
```

`PaywallRewardAdButton` (section 9.3) tự ẩn nếu:
- `rewardAdProvider == nil`, hoặc
- `config.rewardAd == .disabled`, hoặc
- `await rewardAdProvider.isReady() == false`.

Khi user tap:
1. Emit `.rewardAdRequested`.
2. Gọi `rewardAdProvider.show()`.
3. Nếu `earned == true` → thực thi `RewardOutcomeAction` theo config → emit `.rewardAdEarned`.
4. Nếu fail/không earned → emit `.rewardAdFailed`, giữ nguyên state paywall.

---

## 6. Event model

```swift
public enum PaywallEvent: Sendable {
    case didAppear(type: PaywallType)
    case willDismiss(context: DismissContext)
    case didDismiss(context: DismissContext)

    case didTapCTA(productID: String)
    case selectionChanged(from: Product?, to: Product?)

    case purchaseStarted(productID: String)
    case purchaseSucceeded(transaction: VerifiedTransaction)
    case purchaseCancelled(productID: String)   // user cancel dialog Apple
    case purchaseFailed(productID: String, error: PaywallError)
    case purchasePending(productID: String)      // SCA, Ask-to-Buy

    case restoreStarted
    case restoreSucceeded(entitlements: Set<Entitlement>)
    case restoreFailed(error: PaywallError)

    case offerCodeRedeemed(code: String)
    case refundRequested(productID: String)

    case rewardAdRequested
    case rewardAdEarned(outcome: RewardOutcome)
    case rewardAdFailed(error: PaywallError)
}
```

`DismissContext` chứa `didPurchase: Bool`, `reason: DismissReason` (user, programmatic, afterPurchase, interceptor).

---

## 7. Error model

```swift
public enum PaywallError: Error, Sendable {
    case network(underlying: Error)
    case storeKit(StoreKitError)
    case productNotFound(id: String)
    case verificationFailed(reason: String)
    case userCancelled
    case pendingApproval                // Ask-to-Buy, SCA
    case interceptorBlocked(reason: String)
    case adapter(providerName: String, underlying: Error)
    case unknown(underlying: Error)
}
```

Mọi error expose ra app đều là `PaywallError` — kể cả từ RevenueCat/Superwall. Adapter tự map về.

---

## 8. State model cho custom UI

Custom paywall view của app chỉ cần quan tâm 3 thứ, lấy qua `@Environment`:

```swift
struct OnboardingPaywallView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        VStack {
            ForEach(manager.selection.available) { product in
                ProductCard(
                    product: product,
                    isSelected: manager.selection.selected?.id == product.id
                ) {
                    manager.selection.selected = product
                }
            }

            PaywallBuyButton()   // lib component, đã wire sẵn
            PaywallRestoreButton()
            PaywallCloseButton()

            if let error = manager.lastError {
                ErrorBanner(error: error)
            }
        }
    }
}
```

App **không cần** viết: fetch product, handle loading, dismiss sheet, forward event analytics, chạy ads trước dismiss. Tất cả do lib lo.

---

## 9. Presentation layer — `PaywallKitUI`

Target riêng, optional. App không muốn dùng có thể implement lớp presentation riêng (vẫn dùng `PaywallKit` core).

### 9.1 `PaywallRegistry`

Registry gắn mỗi `PaywallType` với **bộ 3**: configuration (shape), view builder (UI), và (internal) presentation resolver.

```swift
@MainActor
public final class PaywallRegistry {
    public func register<V: View>(
        _ type: PaywallType,
        config: PaywallConfiguration,
        @ViewBuilder view: @escaping () -> V
    )
}
```

Ví dụ đầy đủ trong section 5.9. Registry là nơi duy nhất cần chỉnh khi app muốn thêm paywall mới — view code không phải biết gì về presentation style / product mode.

### 9.2 `.paywallPresenter()` — view modifier

Gắn ở root view (app `WindowGroup` hoặc `TabView`). Tự động:
- Observe `manager.presentedType`.
- Resolve `PresentationStyle` **từ config của paywall đang show** (không phải global) → sheet / fullScreenCover / popup / custom cho từng type.
- Gọi interceptor chain trước dismiss.
- Forward event.

```swift
@main
struct MyApp: App {
    @State private var manager = PaywallManager(...)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(manager)
                .paywallPresenter(registry: registry)  // style per-type, lấy từ config
        }
    }
}
```

`popup` style dùng native SwiftUI overlay + backdrop + spring animation (không dùng sheet để tránh drag-to-dismiss). `.custom` cho app override hoàn toàn transition (ví dụ zoom từ button trigger).

### 9.3 Built-in UI components

Component có hành vi chuẩn (loading state, error state, disabled khi `isLoading`), style do app quyết định qua `ButtonStyle`:

- `PaywallBuyButton` — đọc `selection.selected`, gọi `manager.purchase()`.
- `PaywallRestoreButton`.
- `PaywallCloseButton` — trigger `manager.dismiss()` (interceptor chain sẽ chạy). Tự ẩn / delay theo `CloseButtonBehavior` trong config.
- `PaywallRewardAdButton` — tự ẩn nếu reward ads `.disabled` hoặc adapter chưa ready. Tap → chạy flow section 5.10 → animate loading.
- `PaywallProductPicker` — helper radio/segmented cho multi-product; tự ẩn khi `selection.isSingleProduct`.
- `PaywallLoadingIndicator` — bind `manager.isLoading`.
- `PaywallErrorBanner` — bind `manager.lastError`.

### 9.4 Preview helpers

```swift
extension PaywallManager {
    public static func preview(
        products: [Product] = .mock,
        entitlements: Set<Entitlement> = []
    ) -> PaywallManager
}

#Preview {
    OnboardingPaywallView()
        .environment(PaywallManager.preview())
}
```

App preview paywall UI mà không đụng StoreKit.

---

## 10. Package structure

```swift
let package = Package(
    name: "PaywallKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PaywallKit", targets: ["PaywallKit"]),
        .library(name: "PaywallKitUI", targets: ["PaywallKitUI"]),
        .library(name: "PaywallKitRevenueCat", targets: ["PaywallKitRevenueCat"]),
        .library(name: "PaywallKitSuperwall", targets: ["PaywallKitSuperwall"]),
    ],
    dependencies: [
        // RevenueCat & Superwall chỉ resolve nếu app import target tương ứng
    ],
    targets: [
        .target(name: "PaywallKit"),                                          // core, 0 dep
        .target(name: "PaywallKitUI", dependencies: ["PaywallKit"]),          // SwiftUI layer
        .target(name: "PaywallKitRevenueCat", dependencies: ["PaywallKit", .product(name: "RevenueCat", package: "purchases-ios")]),
        .target(name: "PaywallKitSuperwall",  dependencies: ["PaywallKit", .product(name: "SuperwallKit", package: "Superwall-iOS")]),
        .testTarget(name: "PaywallKitTests", dependencies: ["PaywallKit"]),
    ]
)
```

App chỉ import cái nào cần → không phải kéo RevenueCat nếu xài native.

---

## 11. Testing strategy

- **`MockProductProvider`** — test double cho `ProductProvider`, cho phép inject fixture products, simulate error, delay.
- **`MockPaywallCache`** — kiểm tra stale-while-revalidate.
- **StoreKit config file** (`.storekit`) cho integration test qua `SKTestSession`.
- **Snapshot test cho PaywallKitUI** — optional, dùng `swift-snapshot-testing`.
- **Concurrency test** — đảm bảo `@MainActor` isolation không break khi interceptor chạy background work.

---

## 12. Finalized defaults

Đã chốt (app có thể override qua config nếu cần):

| # | Vấn đề | Quyết định |
|---|--------|-----------|
| 1 | Paywall config source | `PaywallType` do app khai báo. `ProductProvider` map type → product ID (StoreKit: map tĩnh; RevenueCat: offering; Superwall: placement). |
| 2 | 2-phase purchase | Auto-finish mặc định. Expose `PurchaseOptions(finishStrategy: .auto \| .manual)` cho consumable / server-ledger. |
| 3 | Entitlement persistence | Keychain (`kSecAttrAccessibleAfterFirstUnlock`) cho snapshot entitlement. Cache metadata ở `.cachesDirectory`. Ephemeral entitlement (reward ads) **không persist**. |
| 4 | Multi-paywall đồng thời | Queue FIFO, depth 1. `config.allowsQueue == false` thì reject với `.paywallBusy`. Expose `manager.queue.clear()`. |
| 5 | Promotional / win-back offers | In scope. `PaywallSelection.selectedOffer` + `manager.eligibleOffers(for:)`. |
| 6 | Optional deps | Separate target (`PaywallKitRevenueCat`, `PaywallKitSuperwall`) — không dùng package traits. |
| 7 | Product mode | `ProductMode.single(id:)` hoặc `.multi(strategy:)`. Strategy mặc định `.firstAvailable`. |
| 8 | Presentation style | Per-paywall-type qua config. Hỗ trợ sheet / fullScreenCover / popup / custom transition. |
| 9 | Reward ads | App cung cấp `RewardAdProvider` adapter. Outcome action: `grantEphemeral` / `switchSelection` / `custom`. Lib không phụ thuộc ads SDK. |
| 10 | Close button | `CloseButtonBehavior`: `alwaysVisible` (default) / `hidden` / `visibleAfter(sec)`. |
| 11 | Cache TTL | Product `3600s`, eligibility `300s`, stale-while-revalidate. |
| 12 | Interceptor timeout | Mỗi hook 5s, quá thì skip (tránh ads hang block dismiss). |
| 13 | Analytics observer | Chạy `Task.detached` priority `.utility`, error isolated. |

---

## 13. Next steps

1. Review & chốt 12 open questions với stakeholder.
2. Lock public API surface (section 5-8) — sau bước này đổi là breaking change.
3. Implement `PaywallKit` core + `StoreKitProductProvider` + test.
4. Implement `PaywallKitUI`.
5. Implement RevenueCat & Superwall adapter.
6. Viết DocC catalog (`Sources/PaywallKit/PaywallKit.docc/`) cho user-facing docs.
7. Viết example app trong `Examples/` minh họa 3 paywall type với 1 backend.
