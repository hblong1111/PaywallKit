# PaywallKit

Swift library gom toàn bộ logic paywall cho iOS 17+: fetch product, cache, purchase, entitlement, event, reward ads — app tự vẽ UI.

## Tính năng

- **StoreKit 2 native** + adapter stub cho RevenueCat & Superwall.
- `@Observable` + async/await — SwiftUI bind trực tiếp.
- Per-paywall ``PaywallConfiguration``: single/multi product, sheet/fullscreen/popup, close button delay, queue.
- `SelectionStrategy`: cheapest, mostExpensive, longestDuration, byID, custom.
- **Interceptor chain** — show ads / confirm / remote-gate trước present / purchase / dismiss.
- **Multi-observer analytics** (Firebase + Mixpanel + AppsFlyer song song, error isolated).
- **Reward ads in paywall** — grant entitlement tạm, switch selection, hoặc custom.
- **Keychain persistence** cho entitlement — cold-launch không flash.
- **PaywallKitUI** (optional target): Registry, `.paywallPresenter()`, built-in `PaywallBuyButton` / `RewardAdButton` / `CloseButton` / `ProductPicker`.

## Requirements

- iOS 17+ (macOS 14+ để build trên host).
- Swift 6.2, Xcode 16+.

## Install

```swift
.package(url: "https://github.com/your-org/PaywallKit.git", from: "0.1.0")
```

Targets:
- `PaywallKit` — core logic.
- `PaywallKitUI` — SwiftUI presentation layer (optional).
- `PaywallKitRevenueCat` — RevenueCat adapter (stub).
- `PaywallKitSuperwall` — Superwall adapter (stub).

## Quick start

```swift
import PaywallKit
import PaywallKitUI

@main
struct MyApp: App {
    @State private var manager = PaywallManager(
        provider: StoreKitProductProvider(productIDMap: [
            .onboarding: ["com.app.monthly", "com.app.yearly"]
        ])
    )
    @State private var registry: PaywallRegistry

    init() {
        let m = PaywallManager(provider: StoreKitProductProvider(productIDMap: [
            .onboarding: ["com.app.monthly", "com.app.yearly"]
        ]))
        _manager = State(initialValue: m)
        _registry = State(initialValue: PaywallRegistry(manager: m))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .paywallPresenter(registry: registry)
                .environment(manager)   // phải đặt SAU .paywallPresenter, không được đảo ngược
                .task { setup() }
        }
    }

    @MainActor
    func setup() {
        registry.register(
            .onboarding,
            config: .init(productMode: .multi(strategy: .mostExpensive), presentation: .fullScreenCover)
        ) { OnboardingPaywallView() }
    }
}

extension PaywallType {
    static let onboarding: PaywallType = "onboarding"
}
```

Trigger:
```swift
Button("Upgrade") { Task { try? await manager.present(.onboarding) } }
```

Feature gate:
```swift
if manager.entitlements.has("pro") { ProContent() } else { Upsell() }
```

## Tài liệu

Docs đầy đủ ở `Sources/PaywallKit/PaywallKit.docc/`. Build DocC:

```bash
swift package --allow-writing-to-directory ./docs generate-documentation \
    --target PaywallKit \
    --output-path ./docs
```

Hoặc mở trong Xcode: Product → Build Documentation.

Nội dung:

- **Getting Started** — tích hợp trong 10 phút.
- **Configuration** — `PaywallConfiguration`, product mode, selection strategy, close button.
- **Custom UI** — vẽ view thuần, bỏ qua built-in.
- **Presentation Styles** — sheet / fullscreen / popup.
- **Purchase & Restore** — flow, finish strategy, pending.
- **Handling Events** — event stream + analytics observer.
- **Reward Ads** — adapter pattern, outcome actions.
- **Entitlement & Gating** — gate feature, persistence, multi-tier.
- **Interceptors** — chặn lifecycle.
- **Analytics** — multi-tracker setup.
- **Switching Backend** — đổi StoreKit / RevenueCat / Superwall.
- **Testing** — mock provider, SKTestSession, snapshot, preview.

Design doc nội bộ: [`Docs/DESIGN.md`](Docs/DESIGN.md).

## Cấu trúc

```
Sources/
├── PaywallKit/            # core logic
│   ├── Core/              # types (PaywallType, PaywallEvent, PaywallError, …)
│   ├── Configuration/     # PaywallConfiguration, enums
│   ├── Protocols/         # ProductProvider, PaywallCache, Interceptor, …
│   ├── Stores/            # EntitlementStore, PaywallSelection
│   ├── Cache/             # InMemoryPaywallCache
│   ├── Providers/         # StoreKitProductProvider
│   ├── Purchase/          # PurchaseCoordinator, Timeout
│   ├── Manager/           # PaywallManager
│   └── PaywallKit.docc/   # DocC catalog
├── PaywallKitUI/          # SwiftUI layer
├── PaywallKitRevenueCat/  # RevenueCat adapter (stub)
└── PaywallKitSuperwall/   # Superwall adapter (stub)
Tests/PaywallKitTests/     # Swift Testing smoke tests
```

## Status

v0.1 draft. Core + UI hoạt động trên StoreKit 2 native. Adapter RevenueCat & Superwall là stub — cần thêm dependency và hoàn thiện. Chưa publish.
