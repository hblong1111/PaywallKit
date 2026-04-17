# Mua hàng & Restore

Flow mua + restore, finish strategy, pending/refund, và cách sync entitlement.

## Overview

PaywallKit gói toàn bộ StoreKit 2 flow vào 2 method async:
- `manager.purchase(_:)` / `manager.purchaseSelected()`
- `manager.restore()`

Mọi kết quả (success / cancelled / pending / error) đều được emit qua ``PaywallEvent`` để analytics & UI cập nhật đồng nhất.

## Mua hàng cơ bản

```swift
Button("Buy") {
    Task {
        do {
            try await manager.purchaseSelected()
        } catch {
            // error đã được lưu vào manager.lastError + emit event
            // thường không cần handle ở đây — UI tự render qua PaywallErrorBanner
        }
    }
}
```

Flow nội bộ:

1. Emit ``PaywallEvent/didTapCTA(productID:)``.
2. Emit ``PaywallEvent/purchaseStarted(productID:)``.
3. Chạy `interceptor.willPurchase(product:)` chain — throw để chặn.
4. Gọi `Product.purchase()`.
5. Verify JWS.
6. `finish()` transaction (theo ``PurchaseOptions/FinishStrategy``).
7. Refresh entitlement từ provider.
8. Emit ``PaywallEvent/purchaseSucceeded(transaction:)``.
9. Dismiss paywall (reason: `.afterPurchase`).

## Finish strategy

`PurchaseOptions.finishStrategy` — auto-finish (mặc định) hay manual-finish.

### `.auto` (default)

Lib gọi `transaction.finish()` ngay sau khi verify. Phù hợp subscription, non-consumable cơ bản.

### `.manual`

Lib emit `purchaseSucceeded` với ``VerifiedTransaction`` nhưng KHÔNG finish. App phải gọi `transaction.finish()` sau khi xác nhận đã deliver nội dung (ví dụ gọi API server ledger xong).

```swift
let manager = PaywallManager(
    provider: StoreKitProductProvider(productIDMap: [...]),
    purchaseOptions: PurchaseOptions(finishStrategy: .manual)
)
```

Subscribe event để lấy transaction:

```swift
Task {
    for await event in manager.events {
        if case .purchaseSucceeded(let transaction) = event {
            await deliverToServer(transaction)
            await transaction.finish()
        }
    }
}
```

## Cancelled

User bấm cancel trong dialog Apple — lib emit ``PaywallEvent/purchaseCancelled(productID:)``, không throw, paywall không dismiss.

## Pending

Ask-to-Buy, SCA (3D Secure) — transaction cần parental/bank approval:

```swift
case .purchasePending(let productID): 
    // UI báo "Waiting for approval"
    // Khi approved, Transaction.updates sẽ emit — lib tự cập nhật entitlement
```

## Restore

```swift
Button("Restore") {
    Task { try? await manager.restore() }
}
```

Flow:
1. Emit ``PaywallEvent/restoreStarted``.
2. Gọi `AppStore.sync()`.
3. Đọc lại `Transaction.currentEntitlements`.
4. Emit ``PaywallEvent/restoreSucceeded(entitlements:)`` hoặc ``PaywallEvent/restoreFailed(error:)``.
5. Cập nhật ``EntitlementStore``.

## Background transaction updates

`PaywallManager` tự subscribe `Transaction.updates` khi khởi tạo, xử lý:
- Auto-renew subscription.
- Mua từ device khác (family sharing).
- Refund được Apple phê duyệt.

Mỗi update → refresh entitlement + emit ``PaywallEvent/purchaseSucceeded(transaction:)``.

## Refund request

Lib chưa ship API refund trực tiếp (`Transaction.beginRefundRequest`). Dùng `VerifiedTransaction.rawTransaction` để gọi thủ công:

```swift
// Sau khi bắt được purchaseSucceeded event:
if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
    try await transaction.rawTransaction.beginRefundRequest(in: scene)
}
```

## Entitlement sync

Sau mỗi purchase/restore thành công, ``EntitlementStore`` được cập nhật:
```swift
manager.entitlements.active        // Set<Entitlement>
manager.entitlements.isSubscribed  // Bool
manager.entitlements.has("pro")    // Bool
```

Entitlement bền (từ purchase/restore) được persist vào Keychain — cold-launch có ngay mà không phải gọi StoreKit.

## Error

Mọi lỗi đều được normalize thành ``PaywallError``:

```swift
switch error {
case .userCancelled:           // user bấm cancel
case .pendingApproval:         // ask-to-buy / SCA
case .productNotFound:         // product ID sai
case .verificationFailed:      // JWS không valid
case .storeKit(let code, _):   // StoreKit error
case .network:                 // connection issue
case .adapter(let name, _):    // lỗi từ RevenueCat/Superwall
case .interceptorBlocked:      // interceptor.willPurchase throw
default: break
}
```

Xem thêm <doc:HandlingEvents>.
