# ``PaywallKit``

Thư viện Swift gom toàn bộ logic paywall (fetch product, cache, purchase, entitlement, event, reward ads) để app tự vẽ UI mà không phải lặp lại plumbing giữa các paywall.

## Overview

PaywallKit chia làm 4 target:

- **`PaywallKit`** — core logic, không phụ thuộc SwiftUI. Chứa ``PaywallManager``, ``EntitlementStore``, ``PaywallSelection``, ``ProductProvider``, cache, interceptor, analytics.
- **`PaywallKitUI`** — SwiftUI layer tùy chọn. Registry, `.paywallPresenter()`, built-in button (`PaywallBuyButton`, `PaywallCloseButton`, `PaywallRewardAdButton`…).
- **`PaywallKitRevenueCat`** — adapter cho RevenueCat (stub, chưa thêm dependency).
- **`PaywallKitSuperwall`** — adapter cho Superwall (stub, chưa thêm dependency).

### Nguyên tắc

> Gom những gì chung ở mọi app; chỉ expose những gì đặc thù theo UI của từng app.

Mọi paywall trong app của bạn nên share cùng ``PaywallManager`` và chỉ khác nhau ở: kiểu layout, config (`PaywallConfiguration`), và adapter (nếu dùng RevenueCat / Superwall).

## Topics

### Bắt đầu

- <doc:GettingStarted>
- <doc:Configuration>

### Xây UI paywall

- <doc:CustomUI>
- <doc:PresentationStyles>

### Flow

- <doc:PurchaseAndRestore>
- <doc:HandlingEvents>
- <doc:RewardAds>
- <doc:EntitlementAndGating>

### Nâng cao

- <doc:Interceptors>
- <doc:Analytics>
- <doc:SwitchingBackend>
- <doc:Testing>

### Core types

- ``PaywallManager``
- ``PaywallType``
- ``PaywallConfiguration``
- ``PaywallEvent``
- ``PaywallError``

### State stores

- ``EntitlementStore``
- ``PaywallSelection``
- ``Entitlement``

### Protocols (adapter)

- ``ProductProvider``
- ``PaywallCache``
- ``PaywallInterceptor``
- ``PaywallAnalyticsObserver``
- ``RewardAdProvider``

### Cache

- ``InMemoryPaywallCache``
- ``CachedProducts``

### Providers

- ``StoreKitProductProvider``

### Purchase

- ``PurchaseOptions``
- ``PurchaseResult``
- ``VerifiedTransaction``

### Configuration types

- ``ProductMode``
- ``SelectionStrategy``
- ``PresentationStyle``
- ``SheetDetent``
- ``BackdropStyle``
- ``CloseButtonBehavior``
- ``RewardAdBehavior``
- ``RewardOutcomeAction``
- ``CustomRewardResult``
- ``RewardOutcome``

### Entitlement persistence

- ``EntitlementPersistence``
- ``KeychainEntitlementPersistence``
- ``InMemoryEntitlementPersistence``

### Dismiss

- ``DismissContext``
- ``DismissReason``
