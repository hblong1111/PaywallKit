# Reward ads trong paywall

Cho user xem reward ads để unlock tạm, đổi sang gói rẻ, hoặc custom outcome — mà lib không phụ thuộc bất kỳ ads SDK nào.

## Overview

Pattern: lib KHÔNG biết AdMob / AppLovin / IronSource. App cung cấp adapter mỏng (``RewardAdProvider``), lib gọi qua đó và apply outcome theo config.

## 1. Viết adapter

```swift
import GoogleMobileAds
import PaywallKit

final class AdMobRewardAdapter: NSObject, RewardAdProvider {
    private var loadedAd: GADRewardedAd?

    func isReady() async -> Bool {
        if loadedAd != nil { return true }
        await preload()
        return loadedAd != nil
    }

    func show() async throws -> RewardOutcome {
        guard let ad = loadedAd,
              let viewController = UIApplication.shared.topViewController else {
            throw PaywallError.rewardAdNotReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            ad.present(fromRootViewController: viewController) {
                let reward = ad.adReward
                continuation.resume(returning: RewardOutcome(
                    earned: true,
                    rewardType: reward.type,
                    rewardAmount: reward.amount.doubleValue
                ))
            }
        }
    }

    private func preload() async {
        loadedAd = try? await GADRewardedAd.load(
            withAdUnitID: "ca-app-pub-xxx/yyy",
            request: GADRequest()
        )
    }
}
```

## 2. Inject vào manager

```swift
let manager = PaywallManager(
    provider: StoreKitProductProvider(productIDMap: [...]),
    rewardAdProvider: AdMobRewardAdapter()
)
```

## 3. Bật trong config

Dùng ``RewardAdBehavior/enabled(outcome:)`` với 1 trong 3 outcome action:

### `.grantEphemeral(id:duration:)` — unlock tạm thời

```swift
registry.register(
    .contentGate,
    config: PaywallConfiguration(
        productMode: .single(productID: "com.app.pro.monthly"),
        presentation: .popup(),
        rewardAd: .enabled(outcome: .grantEphemeral(id: "pro", duration: 300))  // 5 phút
    )
) { ContentGatePaywallView() }
```

Sau khi user xem ad:
- ``EntitlementStore/grantEphemeral(_:until:)`` được gọi.
- `manager.entitlements.has("pro")` trả true.
- 5 phút sau tự revoke.

**Không persist** — mất khi kill app. Phù hợp "unlock bài viết này", "skip quảng cáo game này".

### `.switchSelection(toProductID:)` — đổi sang gói rẻ hơn

```swift
rewardAd: .enabled(outcome: .switchSelection(toProductID: "com.app.pro.monthly.discount"))
```

Khi user xem ad xong, ``PaywallSelection/selected`` chuyển sang product ID chỉ định. User thấy giá giảm và có thể mua.

Use case: "Xem ad để nhận 50% off".

### `.custom` — app tự quyết

```swift
rewardAd: .enabled(outcome: .custom { outcome in
    if outcome.rewardAmount ?? 0 >= 100 {
        return .grantEphemeral(id: "pro", duration: 3600)
    } else {
        return .grantEphemeral(id: "pro", duration: 300)
    }
})
```

Closure nhận ``RewardOutcome`` (earned, rewardType, rewardAmount từ ads SDK), return ``CustomRewardResult``:
- `.grantEphemeral(id:duration:)`
- `.switchSelection(toProductID:)`
- `.dismissPaywall`
- `.noop`

## 4. UI button

Built-in ``PaywallKitUI/PaywallRewardAdButton`` tự ẩn khi:
- ``RewardAdProvider`` = nil.
- Config `rewardAd` = `.disabled`.
- `provider.isReady()` trả false.

```swift
PaywallRewardAdButton {
    HStack {
        Image(systemName: "play.rectangle.fill")
        Text("Watch ad to unlock 5 min")
    }
    .padding()
    .background(.purple.opacity(0.2), in: Capsule())
}
```

## 5. Event

Subscribe để track:

```swift
case .rewardAdRequested:        // user tap
case .rewardAdEarned(let outcome):  // xem xong, earned
case .rewardAdFailed(let error):    // load fail / user bỏ dở
```

## Flow end-to-end

```
┌─────────────────────────────────────────────────────────────┐
│ User tap PaywallRewardAdButton                              │
│     │                                                        │
│     ▼                                                        │
│ manager.showRewardAd()                                       │
│     │                                                        │
│     ▼ emit .rewardAdRequested                                │
│ rewardAdProvider.show() ──────► AdMobRewardAdapter          │
│     │                            │                           │
│     │                            ▼ GADRewardedAd.present    │
│     │                            │                           │
│     │                            ◄──── user xem xong        │
│     ▼                                                        │
│ RewardOutcome(earned: true)                                  │
│     │                                                        │
│     ▼ emit .rewardAdEarned                                   │
│ Apply RewardOutcomeAction:                                   │
│     • .grantEphemeral → entitlements.grantEphemeral(...)    │
│     • .switchSelection → selection.selectByID(...)          │
│     • .custom → closure → apply CustomRewardResult          │
└─────────────────────────────────────────────────────────────┘
```

## Không bắt buộc

Nếu app không có reward ads, đơn giản:
- Không pass `rewardAdProvider` vào `PaywallManager`.
- `PaywallRewardAdButton` tự ẩn hoàn toàn.
- Không có event reward-* phát sinh.
