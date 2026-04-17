# Analytics observer

Tracking multi-provider song song (Firebase + Mixpanel + AppsFlyer + ...), error isolated, không block main thread.

## Overview

``PaywallAnalyticsObserver`` là protocol đơn giản:

```swift
public protocol PaywallAnalyticsObserver: Sendable {
    func observe(_ event: PaywallEvent) async
}
```

Lib chạy mỗi observer trong `Task.detached(priority: .utility)` — error isolated, main actor không bị block.

## Đăng ký nhiều tracker

```swift
let manager = PaywallManager(
    provider: provider,
    analytics: [
        FirebaseAnalyticsObserver(),
        MixpanelObserver(),
        AppsFlyerObserver(),
        InternalDebugLogger()
    ]
)
```

1 event → cả 4 observer cùng nhận song song. Observer A crash không ảnh hưởng B, C, D.

## Viết observer

### Firebase

```swift
import FirebaseAnalytics

struct FirebaseAnalyticsObserver: PaywallAnalyticsObserver {
    func observe(_ event: PaywallEvent) async {
        let (name, params) = mapping(event)
        Analytics.logEvent(name, parameters: params)
    }

    private func mapping(_ event: PaywallEvent) -> (String, [String: Any]) {
        switch event {
        case .didAppear(let type):
            return ("paywall_shown", ["type": type.rawValue])
        case .purchaseStarted(let pid):
            return ("purchase_started", ["product_id": pid])
        case .purchaseSucceeded(let tx):
            return ("purchase_completed", [
                "product_id": tx.productID,
                "transaction_id": String(tx.id)
            ])
        case .purchaseFailed(let pid, let err):
            return ("purchase_failed", [
                "product_id": pid,
                "error": err.errorDescription ?? "unknown"
            ])
        case .purchaseCancelled(let pid):
            return ("purchase_cancelled", ["product_id": pid])
        case .didDismiss(let ctx):
            return ("paywall_dismissed", [
                "type": ctx.paywallType.rawValue,
                "did_purchase": ctx.didPurchase,
                "reason": String(describing: ctx.reason)
            ])
        default:
            return ("paywall_event", [:])
        }
    }
}
```

### Mixpanel

```swift
import Mixpanel

struct MixpanelObserver: PaywallAnalyticsObserver {
    func observe(_ event: PaywallEvent) async {
        Mixpanel.mainInstance().track(
            event: event.analyticsName,
            properties: event.analyticsProperties
        )
    }
}
```

### AppsFlyer (attribution)

```swift
import AppsFlyerLib

struct AppsFlyerObserver: PaywallAnalyticsObserver {
    func observe(_ event: PaywallEvent) async {
        switch event {
        case .purchaseSucceeded(let tx):
            AppsFlyerLib.shared().logEvent(AFEventPurchase, withValues: [
                AFEventParamContentId: tx.productID,
                AFEventParamPrice: 0,  // lấy từ Product nếu cần
            ])
        default: break  // chỉ track purchase
        }
    }
}
```

## Rule of thumb

| Event | Nên track? |
|---|---|
| `didAppear` | ✅ Luôn — phễu bắt đầu. |
| `didDismiss` (didPurchase=false) | ✅ Drop-off funnel. |
| `didTapCTA` | ✅ Intent metric. |
| `purchaseStarted` / `Succeeded` / `Failed` / `Cancelled` | ✅ Revenue & funnel. |
| `restoreStarted/Succeeded/Failed` | ✅ Ít volume, dễ gom. |
| `rewardAdRequested/Earned/Failed` | ✅ Nếu có ads flow. |
| `selectionChanged` | ⚠️ Có thể ồn ào, chỉ track nếu cần optimize picker UI. |
| `purchasePending` | ⚠️ Edge case, chủ yếu debug. |

## Observer vs Event stream

| Dùng observer khi | Dùng event stream khi |
|---|---|
| Fire-and-forget tracking | Cần đáp trả bằng action |
| Đa tracker song song | 1 consumer duy nhất |
| Không care nếu chậm hoặc fail | Cần sequencing chính xác |
| Không block main | Có thể block task |

Ví dụ "deliver nội dung sau purchase" nên qua event stream (business-critical), không qua observer (có thể chậm, có thể fail).

## Testing

```swift
actor SpyObserver: PaywallAnalyticsObserver {
    private(set) var received: [PaywallEvent] = []

    func observe(_ event: PaywallEvent) async {
        received.append(event)
    }

    func events() async -> [PaywallEvent] { received }
}
```

Dùng trong test:

```swift
let spy = SpyObserver()
let manager = PaywallManager(provider: MockProvider(), analytics: [spy])
try await manager.present(.onboarding)

let events = await spy.events()
#expect(events.contains { if case .didAppear = $0 { return true }; return false })
```
