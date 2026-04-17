# Interceptor — chặn lifecycle

Inject logic vào 3 điểm quan trọng: trước present, trước purchase, trước dismiss. Use case chính: show ads trước khi dismiss, confirm dialog, remote gating.

## Overview

``PaywallInterceptor`` có 3 hook, chạy tuần tự theo thứ tự đăng ký:

| Hook | Chặn được? | Timeout |
|---|---|---|
| `willPresent(type:)` | Có (throw) | 5s → skip |
| `willPurchase(product:)` | Có (throw) | 5s → throw `.interceptorBlocked` |
| `willDismiss(context:)` | Không | 5s → skip |

Timeout mặc định 5 giây (config qua ``PurchaseOptions/interceptorTimeout``).

## Use case 1: show ads interstitial trước dismiss

Paywall free không mua → show interstitial.

```swift
import GoogleMobileAds

final class AdInterceptor: PaywallInterceptor {
    func willDismiss(context: DismissContext) async {
        guard !context.didPurchase else { return }  // đã mua thì không show ads

        await withCheckedContinuation { continuation in
            InterstitialAdManager.shared.show {
                continuation.resume()
            }
        }
    }
}

let manager = PaywallManager(
    provider: provider,
    interceptors: [AdInterceptor()]
)
```

Flow:
1. User bấm close.
2. Lib emit ``PaywallEvent/willDismiss(context:)``.
3. `AdInterceptor.willDismiss` chạy → show ads → `await` hết.
4. Lib dismiss paywall.
5. Emit `.didDismiss`.

`willDismiss` có timeout 5s — nếu ads load quá lâu, lib skip và dismiss.

## Use case 2: confirm trước khi purchase

```swift
@MainActor
final class ConfirmInterceptor: PaywallInterceptor {
    let presenter: any ConfirmPresenting

    func willPurchase(product: Product) async throws {
        let confirmed = await presenter.showConfirm(
            message: "Xác nhận mua \(product.displayName) với giá \(product.displayPrice)?"
        )
        guard confirmed else {
            throw PaywallError.interceptorBlocked(reason: "user_declined_confirm")
        }
    }
}
```

Throw → lib không gọi `Product.purchase()`, emit ``PaywallEvent/purchaseFailed(productID:error:)`` với `.interceptorBlocked`.

## Use case 3: remote gating

Block present nếu feature bị disable server-side:

```swift
struct RemoteGateInterceptor: PaywallInterceptor {
    func willPresent(type: PaywallType) async throws {
        let config = await RemoteConfig.shared.fetch()
        if config.disabledPaywalls.contains(type.rawValue) {
            throw PaywallError.interceptorBlocked(reason: "disabled_by_remote_config")
        }
    }
}
```

## Use case 4: track custom event trước show

```swift
struct AnalyticsInterceptor: PaywallInterceptor {
    func willPresent(type: PaywallType) async throws {
        // attribution enrichment
        Analytics.setUserProperty("about_to_see_\(type.rawValue)", forName: "funnel_step")
    }
}
```

> Khác với ``PaywallAnalyticsObserver``: interceptor chạy trước event emit, chặn được flow. Observer chạy song song, không chặn được. Dùng interceptor cho *đồng bộ pre-action*, observer cho *broadcast*.

## Chain order

```swift
interceptors: [
    RemoteGateInterceptor(),   // 1. Gate trước
    AnalyticsInterceptor(),    // 2. Track
    ConfirmInterceptor(),      // 3. Confirm
    AdInterceptor()            // 4. Ads on dismiss
]
```

Thứ tự mảng = thứ tự chạy. Throw ở bất kỳ bước nào sẽ stop chain (cho `willPresent` / `willPurchase`).

## Default implementation

Protocol extension cung cấp no-op cho cả 3 method → bạn chỉ override những hook cần:

```swift
struct OnlyCareDismiss: PaywallInterceptor {
    func willDismiss(context: DismissContext) async {
        // ...
    }
    // willPresent / willPurchase không override → no-op
}
```

## DismissContext

```swift
public struct DismissContext {
    let paywallType: PaywallType
    let reason: DismissReason       // .user, .programmatic, .afterPurchase, .interceptor, .queueEvicted
    let didPurchase: Bool
    let purchasedProductID: String?
}
```

Phân biệt `reason: .afterPurchase` vs `.user` rất quan trọng cho ads logic — đừng show interstitial ngay sau khi user vừa trả tiền.

## Testing interceptor

```swift
final class SpyInterceptor: PaywallInterceptor {
    var willPresentCalls: [PaywallType] = []
    var shouldBlockPurchase = false

    func willPresent(type: PaywallType) async throws {
        willPresentCalls.append(type)
    }

    func willPurchase(product: Product) async throws {
        if shouldBlockPurchase {
            throw PaywallError.interceptorBlocked(reason: "test")
        }
    }
}
```
