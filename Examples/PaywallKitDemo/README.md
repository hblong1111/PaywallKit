# PaywallKit Demo

Demo iOS app cho PaywallKit: 3 paywall type (fullscreen onboarding, popup feature-gate, sheet settings), mock reward ads, logging interceptor, debug analytics.

## Chạy

### Yêu cầu
- Xcode 16+
- Simulator iOS 17+
- (Khuyến khích) [XcodeGen](https://github.com/yonaskolb/XcodeGen) — cài qua Homebrew: `brew install xcodegen`.

### Cách 1 — dùng XcodeGen (khuyến khích)

```bash
cd Examples/PaywallKitDemo
xcodegen generate
open PaywallKitDemo.xcodeproj
```

Sau khi Xcode mở:
- Chọn simulator iOS 17+.
- Bấm ▶️ Run.

Scheme đã config `Products.storekit` — purchase chạy local qua `StoreKit Test`, không cần App Store Connect.

### Cách 2 — tạo Xcode project thủ công

1. Xcode → `File → New → Project → iOS → App`.
2. Product Name: `PaywallKitDemo`, Interface: SwiftUI, Language: Swift, Storage: None.
3. Tạo ở thư mục khác bất kỳ; sau đó:
   - Xóa `ContentView.swift` và `PaywallKitDemoApp.swift` mặc định.
   - Drag toàn bộ file trong `Examples/PaywallKitDemo/Sources/` vào project.
4. `File → Add Package Dependencies → Add Local` → chọn thư mục root `PaywallKit/`. Thêm cả 2 product: `PaywallKit` và `PaywallKitUI`.
5. Drag `Resources/Products.storekit` vào project (chọn "Copy items if needed").
6. Edit Scheme → Run → Options → **StoreKit Configuration** = `Products.storekit`.
7. Deployment target: iOS 17+.
8. Run.

## Gì trong demo

### 3 tab

- **Home** — nút "Show Onboarding Paywall" → full-screen, multi product, close sau 3s, có reward ads button grant 2 phút Pro tạm.
- **Feature** — feature locked. Nút "Unlock now" → popup với 1 product (yearly).
- **Settings** — list entitlement hiện tại + nút show settings paywall (sheet, multi product, default chọn rẻ nhất) + Restore + Clear.

### Debug tools in demo

- **`LogInterceptor`** — log lifecycle + giả lập show ads 1s trước khi dismiss (nếu chưa mua).
- **`DebugAnalyticsObserver`** — log event ra console với emoji.
- **`MockRewardAdProvider`** — delay 2s rồi trả `earned: true`.

Mở **console** khi chạy để thấy log đầy đủ của lifecycle + event.

### StoreKit products

| Product ID | Type | Price |
|---|---|---|
| `com.paywallkit.demo.pro.monthly` | Auto-renewable | $4.99 / month |
| `com.paywallkit.demo.pro.yearly` | Auto-renewable | $39.99 / year |
| `com.paywallkit.demo.pro.lifetime` | Non-consumable | $79.99 |

Xem `Resources/Products.storekit`.

## Test các kịch bản

Xcode → **Debug → StoreKit → Manage Transactions** để simulate:
- Refund
- Resubscribe
- Expire subscription
- Revoke entitlement

Xcode → **Edit Scheme → StoreKit Configuration → Settings** để đổi:
- Ask to Buy
- Load time
- Transaction failure rate

## Troubleshooting

**Không thấy product trong paywall:**
- Check scheme có point đúng `Products.storekit` không.
- Check `productIDMap` trong `PaywallKitDemoApp.swift` có trùng product ID trong `Products.storekit` không.

**Entitlement không persist giữa launch:**
- Demo dùng `InMemoryEntitlementPersistence()` nên mất khi kill app (cố ý, để dễ test lại). Đổi sang `KeychainEntitlementPersistence()` nếu cần persist.

**Popup không dismiss khi tap backdrop:**
- Gesture đang bị chặn bởi view bên trong popup — thêm `.contentShape(Rectangle())` vào backdrop hoặc kiểm tra z-order.

## Cấu trúc

```
Examples/PaywallKitDemo/
├── project.yml                       # XcodeGen config
├── README.md
├── Sources/
│   ├── PaywallKitDemoApp.swift       # @main + PaywallManager wiring
│   ├── RootView.swift                # TabView + Home/Feature/Settings
│   ├── PaywallTypes.swift            # extension PaywallType
│   ├── OnboardingPaywallView.swift   # fullscreen paywall UI
│   ├── FeatureGatePaywallView.swift  # popup paywall UI
│   ├── SettingsPaywallView.swift     # sheet paywall UI
│   ├── LogInterceptor.swift          # demo interceptor
│   ├── DebugAnalyticsObserver.swift  # console analytics
│   └── MockRewardAdProvider.swift    # fake reward ads
└── Resources/
    └── Products.storekit             # StoreKit test config
```
