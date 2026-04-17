# Handler các sự kiện paywall

Subscribe `manager.events` để react với lifecycle: show, dismiss, tap CTA, purchase, restore, reward ads.

## Overview

``PaywallEvent`` là enum cover toàn bộ lifecycle của paywall. Có 2 cách nhận event:

1. **`AsyncStream<PaywallEvent>`** (qua ``PaywallManager/events``) — single consumer, cho business logic.
2. **``PaywallAnalyticsObserver``** — multi consumer, fire-and-forget, cho tracking.

## Event stream

```swift
Task {
    for await event in manager.events {
        switch event {
        case .didAppear(let type):
            print("Paywall \(type.rawValue) shown")
        case .purchaseSucceeded(let transaction):
            await deliverPremiumContent(transaction.productID)
        case .didDismiss(let ctx) where !ctx.didPurchase:
            // user bỏ không mua
            scheduleWinBackCampaign()
        default:
            break
        }
    }
}
```

Stream dùng `.bufferingNewest(32)` — buffer 32 event gần nhất, event cũ bị drop nếu consumer chậm.

## Các event chính

### Lifecycle

| Event | Khi nào |
|---|---|
| ``PaywallEvent/didAppear(type:)`` | Paywall vừa hiện xong (sau khi product load). |
| ``PaywallEvent/willDismiss(context:)`` | Paywall sắp đóng. ``DismissContext`` chứa `didPurchase`, `reason`. |
| ``PaywallEvent/didDismiss(context:)`` | Paywall đã đóng xong. |

### Interaction

| Event | Khi nào |
|---|---|
| ``PaywallEvent/didTapCTA(productID:)`` | User tap nút mua. Emit ngay trước `purchaseStarted`. |
| ``PaywallEvent/selectionChanged(from:to:)`` | User đổi product trong multi-product paywall. |

### Purchase

| Event | Khi nào |
|---|---|
| ``PaywallEvent/purchaseStarted(productID:)`` | Bắt đầu gọi StoreKit. |
| ``PaywallEvent/purchaseSucceeded(transaction:)`` | Mua thành công + verified. |
| ``PaywallEvent/purchaseCancelled(productID:)`` | User cancel dialog Apple. |
| ``PaywallEvent/purchaseFailed(productID:error:)`` | Fail vì lý do khác (network, verification, adapter). |
| ``PaywallEvent/purchasePending(productID:)`` | Ask-to-Buy / SCA. |

### Restore

| Event | Khi nào |
|---|---|
| ``PaywallEvent/restoreStarted`` | |
| ``PaywallEvent/restoreSucceeded(entitlements:)`` | |
| ``PaywallEvent/restoreFailed(error:)`` | |

### Reward ads

| Event | Khi nào |
|---|---|
| ``PaywallEvent/rewardAdRequested`` | User tap "Watch ad". |
| ``PaywallEvent/rewardAdEarned(outcome:)`` | Đã xem hết, earned. |
| ``PaywallEvent/rewardAdFailed(error:)`` | Load fail / user bỏ dở. |

## Analytics observer

Thay vì consume event stream, thường ta muốn **nhiều** tracker song song (Firebase, Mixpanel, AppsFlyer). Dùng ``PaywallAnalyticsObserver``:

```swift
struct FirebaseAnalyticsObserver: PaywallAnalyticsObserver {
    func observe(_ event: PaywallEvent) async {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
}

struct MixpanelObserver: PaywallAnalyticsObserver {
    func observe(_ event: PaywallEvent) async {
        Mixpanel.mainInstance().track(event: event.name, properties: event.parameters)
    }
}

let manager = PaywallManager(
    provider: provider,
    analytics: [FirebaseAnalyticsObserver(), MixpanelObserver()]
)
```

Mỗi observer chạy trong `Task.detached(priority: .utility)` — error isolated, không ảnh hưởng main và không ảnh hưởng observer khác.

## Map event → analytics name

Ví dụ pattern:

```swift
extension PaywallEvent {
    var name: String {
        switch self {
        case .didAppear: return "paywall_shown"
        case .didDismiss: return "paywall_dismissed"
        case .didTapCTA: return "paywall_cta_tapped"
        case .purchaseStarted: return "purchase_started"
        case .purchaseSucceeded: return "purchase_succeeded"
        case .purchaseFailed: return "purchase_failed"
        case .purchaseCancelled: return "purchase_cancelled"
        case .restoreStarted: return "restore_started"
        case .restoreSucceeded: return "restore_succeeded"
        case .restoreFailed: return "restore_failed"
        case .rewardAdRequested: return "reward_ad_requested"
        case .rewardAdEarned: return "reward_ad_earned"
        default: return "paywall_event"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .didAppear(let type):
            return ["paywall_type": type.rawValue]
        case .purchaseSucceeded(let transaction):
            return ["product_id": transaction.productID, "transaction_id": transaction.id]
        case .purchaseFailed(let productID, let error):
            return ["product_id": productID, "error": String(describing: error)]
        // ...
        default: return [:]
        }
    }
}
```

## Event vs Observer: khi nào dùng cái nào

| Use case | Cơ chế |
|---|---|
| Deliver content sau purchase | `events` stream (business logic) |
| Update UI ngoài paywall | `@Observable` state (`manager.entitlements`, `isSubscribed`) |
| Track Firebase / Mixpanel | ``PaywallAnalyticsObserver`` |
| Log debug | ``PaywallAnalyticsObserver`` hoặc `events` stream |
| Win-back campaign sau dismiss | `events` stream (single consumer logic) |

**Rule of thumb:** fire-and-forget → observer. Business decision quan trọng → stream.
