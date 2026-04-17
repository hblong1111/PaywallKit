# Đổi backend (StoreKit / RevenueCat / Superwall)

Chuyển đổi giữa 3 backend bằng cách đổi ``ProductProvider``. UI và business logic không đổi.

## Overview

Toàn bộ code app chỉ biết ``PaywallManager``. Backend là detail được giấu sau ``ProductProvider``. Đổi backend = đổi 1 dòng ở init.

## 1. StoreKit 2 native (default)

```swift
import PaywallKit

let provider = StoreKitProductProvider(productIDMap: [
    .onboarding: ["com.app.monthly", "com.app.yearly"],
    .featureGate: ["com.app.yearly"]
])

let manager = PaywallManager(provider: provider)
```

**Khi dùng:**
- App vừa ra, chưa cần server-side receipt validation.
- Không cần A/B test paywall.
- Muốn zero dependency bên thứ 3.

**Giới hạn:**
- Self-manage entitlement ở client (lib đã xử lý với Keychain).
- Không có analytics panel (phải tự gắn).
- Không có paywall config remote.

## 2. RevenueCat

```swift
import PaywallKitRevenueCat
import RevenueCat

// Init RevenueCat ở app launch
Purchases.configure(withAPIKey: "appl_xxx")

let provider = RevenueCatProductProvider()
let manager = PaywallManager(provider: provider)
```

**Khi dùng:**
- Cần dashboard phân tích revenue chi tiết.
- Cần A/B test paywall và offering.
- App đa platform (iOS + Android) cần đồng bộ entitlement.
- Cần server-side receipt validation sẵn.

**Mapping:**
- ``PaywallType`` → RevenueCat `Offering`:
  ```swift
  // Map PaywallType.onboarding → Offering "onboarding" trong RevenueCat dashboard
  ```
- ``Entitlement.ID`` → RevenueCat `Entitlement`:
  ```swift
  // Map Entitlement.ID("pro") → RevenueCat entitlement "pro"
  ```

> **Lưu ý:** Target `PaywallKitRevenueCat` hiện là stub. Để dùng thật, thêm `purchases-ios` package vào Package.swift dependencies và hoàn thiện file `RevenueCatProductProvider.swift`.

## 3. Superwall

```swift
import PaywallKitSuperwall
import SuperwallKit

Superwall.configure(apiKey: "pk_xxx")

let provider = SuperwallProductProvider()
let manager = PaywallManager(provider: provider)
```

**Khi dùng:**
- Muốn paywall UI controlled remote (thay đổi layout không cần release).
- Cần placement-based trigger phức tạp.
- Team product muốn A/B test paywall thường xuyên.

**Mapping:**
- ``PaywallType`` → Superwall `placement`.
- Product set trong Superwall dashboard.

> Target `PaywallKitSuperwall` hiện là stub. Hoàn thiện khi add `Superwall-iOS` dependency.

## Khi nào đổi backend?

| Giai đoạn | Backend phù hợp |
|---|---|
| MVP / đang validate idea | StoreKit native |
| Đã launch, muốn phân tích revenue | RevenueCat |
| Tối ưu conversion, A/B test liên tục | Superwall hoặc RevenueCat + Superwall |
| Nhiều platform | RevenueCat |

Đổi giữa 3 backend **không yêu cầu** đổi UI code hay logic feature-gate — chỉ đổi provider.

## Kết hợp nhiều backend

Use case hiếm nhưng có thể: paywall A dùng Superwall (có A/B), paywall B dùng StoreKit native (đơn giản).

```swift
// Tạo 2 manager độc lập
let superwallManager = PaywallManager(provider: SuperwallProductProvider())
let storeKitManager = PaywallManager(provider: StoreKitProductProvider(productIDMap: [...]))
```

Không khuyến khích — phức tạp entitlement sync. Tốt hơn viết 1 composite provider:

```swift
struct HybridProvider: ProductProvider {
    let storeKit: StoreKitProductProvider
    let superwall: SuperwallProductProvider

    func products(for type: PaywallType, mode: ProductMode) async throws -> [Product] {
        switch type {
        case .onboarding, .promo:
            return try await superwall.products(for: type, mode: mode)
        default:
            return try await storeKit.products(for: type, mode: mode)
        }
    }
    // ... forward khác
}
```

## Migration

Từ StoreKit native → RevenueCat / Superwall:

1. Chưa release RC + SW: chỉ cần đổi provider, rebuild.
2. Đã có user mua qua StoreKit native:
   - Set up RevenueCat / Superwall nhận Apple transaction (họ đọc lại `Transaction.currentEntitlements`).
   - Lần launch đầu sau update, entitlement từ StoreKit tự sync qua RC/SW.
   - ``EntitlementStore`` re-populate từ `provider.refreshEntitlements()`.

Không mất data, không cần migration script.
