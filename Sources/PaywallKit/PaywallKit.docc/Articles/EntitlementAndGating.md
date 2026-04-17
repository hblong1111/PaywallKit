# Quản lý entitlement & gate feature

Check trạng thái đã mua, gate feature, grant tạm thời, và đồng bộ giữa devices.

## Overview

``EntitlementStore`` là source of truth cho "user đã mua gì". `@Observable` + `@MainActor` — SwiftUI view bind trực tiếp:

```swift
@Environment(PaywallManager.self) private var manager

var body: some View {
    if manager.entitlements.has("pro") {
        ProContent()
    } else {
        UpsellContent()
    }
}
```

## Entitlement model

``Entitlement`` là struct có:
- `id: Entitlement.ID` — identifier (vd: "pro", "premium", "lifetime").
- `productID: String?` — product ID gắn với entitlement này.
- `expiresAt: Date?` — nil = lifetime.
- `isEphemeral: Bool` — true = reward ads grant, không persist.
- `source: Source` — `.purchase`, `.restore`, `.rewardAd`, `.promotion`, `.manual`.

## Đọc entitlement

```swift
let store = manager.entitlements

store.active                // Set<Entitlement>
store.isSubscribed          // có bất kỳ non-ephemeral entitlement nào active không
store.hasAnyActive          // kể cả ephemeral
store.has("pro")            // Entitlement.ID
store.entitlement(for: "pro")  // Entitlement? (nếu active)
```

## Cách entitlement được cập nhật

### Tự động (bình thường)

1. **Sau mỗi purchase thành công** — lib gọi `provider.refreshEntitlements()` và `store.set(_:)`.
2. **Sau restore** — `store.set(_:)` với kết quả từ provider.
3. **Transaction.updates** — khi Apple gửi update background (auto-renew, family share, refund), `handleBackgroundTransaction` refresh.

App không cần làm gì thủ công.

### Manual grant (edge case)

```swift
// Cấp entitlement từ code (ví dụ: promo code redeem, server push)
manager.entitlements.upsert(Entitlement(
    id: "pro",
    expiresAt: Date().addingTimeInterval(30 * 86400),
    source: .promotion
))

// Revoke (ví dụ: backend báo refund)
manager.entitlements.revoke("pro")
```

### Ephemeral grant (reward ads)

```swift
manager.entitlements.grantEphemeral("pro", until: Date().addingTimeInterval(300))
```

Auto-revoke sau 5 phút, không persist. Xem <doc:RewardAds>.

## Persistence

Mặc định dùng ``KeychainEntitlementPersistence`` — lưu vào Keychain với `kSecAttrAccessibleAfterFirstUnlock`.

- **Sống qua reinstall** (nếu iCloud backup bật).
- **Sống qua app launch** — cold-launch có ngay, không cần đợi StoreKit.
- **Protected khỏi jailbreak truy cập trực tiếp**.

**Đổi persistence:**

```swift
let manager = PaywallManager(
    provider: provider,
    entitlementPersistence: InMemoryEntitlementPersistence()  // test
)
```

Tự custom (ví dụ: sync với server ledger):

```swift
struct MyServerBackedPersistence: EntitlementPersistence {
    func load() throws -> Set<Entitlement> { /* GET /entitlements */ }
    func save(_ entitlements: Set<Entitlement>) throws { /* PUT /entitlements */ }
    func clear() throws { /* DELETE */ }
}
```

## Gate feature

### Gate trong view

```swift
struct EditPhotoView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        if manager.entitlements.has("pro") {
            AdvancedEditor()
        } else {
            Button("Unlock advanced editor") {
                Task { try? await manager.present(.featureGate) }
            }
        }
    }
}
```

### Gate trong logic

```swift
func applyFilter(_ filter: Filter) {
    guard manager.entitlements.has("pro") else {
        Task { try? await manager.present(.featureGate) }
        return
    }
    // apply
}
```

## Multiple entitlement tier

Nhiều entitlement ID cho các tier khác nhau:

```swift
extension Entitlement.ID {
    static let basic: Self = "basic"
    static let pro: Self = "pro"
    static let team: Self = "team"
}

// Ở provider map product → entitlement ID:
// com.app.basic.monthly → basic
// com.app.pro.monthly → pro
// com.app.team.monthly → team

// Check:
if manager.entitlements.has(.team) {
    // team features
} else if manager.entitlements.has(.pro) {
    // pro features
} else if manager.entitlements.has(.basic) {
    // basic features
}
```

Mặc định ``StoreKitProductProvider`` map 1:1 product ID → entitlement ID. Nếu cần ghép nhiều product → 1 entitlement (ví dụ monthly + yearly cùng grant "pro"), viết provider custom hoặc post-process `set(_:)`.

## Sync giữa devices

- **Auto-renew subscription:** Apple tự đồng bộ qua `Transaction.updates` → lib tự refresh.
- **Family sharing:** tương tự, `Transaction.currentEntitlements` trả về.
- **Promotional offer redeemed trên device khác:** ngay khi app foreground, lib gọi `refreshEntitlements()` và cập nhật.

Nếu muốn force sync ngay:

```swift
Task { try? await manager.restore() }
```

## Cold-launch behavior

```
App launch
    │
    ▼
PaywallManager.init
    │
    ▼
EntitlementStore.init
    │
    ▼
persistence.load()  ────► Keychain read (sync, ~1ms)
    │
    ▼
store.active = [...persisted entitlements...]
    │
    ▼
UI render — manager.entitlements.has("pro") = true ngay
    │
    ▼ (background)
provider.refreshEntitlements() — verify với Apple
    │
    ▼
store.set(...)  ────► update UI nếu khác
```

Không có flash "locked → unlocked" trên cold-launch — quan trọng cho UX app paid.
