# Cấu hình paywall

``PaywallConfiguration`` gom mọi quyết định về shape và hành vi của 1 paywall type vào 1 struct, khai báo 1 lần lúc register.

## Overview

Mỗi ``PaywallType`` gắn với đúng 1 ``PaywallConfiguration``. Configuration quyết định:
- Có bao nhiêu product, default chọn cái nào.
- Paywall hiện dạng sheet / full screen / popup.
- Close button có ngay / delay / không có.
- Reward ads bật hay tắt.
- Được xếp hàng khi paywall khác đang hiển thị hay không.

## Ví dụ đầy đủ

```swift
registry.register(
    .onboarding,
    config: PaywallConfiguration(
        productMode: .multi(strategy: .mostExpensive),
        presentation: .fullScreenCover,
        closeButton: .visibleAfter(3),
        rewardAd: .enabled(outcome: .grantEphemeral(id: "pro", duration: 300)),
        allowsQueue: false
    )
) {
    OnboardingPaywallView()
}
```

## Product mode

``ProductMode`` — paywall có 1 hay nhiều product.

### Single product

```swift
productMode: .single(productID: "com.myapp.pro.yearly")
```

- Provider chỉ fetch đúng product ID chỉ định.
- ``PaywallSelection/selected`` luôn là product đó (hoặc nil nếu fetch fail).
- ``PaywallSelection/isSingleProduct`` trả `true` — helper để UI ẩn product picker.

### Multi product

```swift
productMode: .multi(strategy: .mostExpensive)
```

Provider fetch danh sách product ID map cho ``PaywallType`` (khai báo trong `StoreKitProductProvider(productIDMap:)`). Sau khi fetch xong, ``SelectionStrategy`` quyết định default selection.

## Selection strategy

``SelectionStrategy`` quyết định *mặc định* product nào được chọn sau khi product list load xong. User vẫn có thể đổi bằng cách tap product khác (``PaywallSelection/selectByID(_:)``).

| Strategy | Ý nghĩa |
|---|---|
| `.firstAvailable` | Lấy phần tử đầu tiên trong list (theo thứ tự provider trả về). |
| `.cheapest` | Product có giá thấp nhất. |
| `.mostExpensive` | Product giá cao nhất — thường để đẩy yearly/lifetime. |
| `.byID("sku")` | Ép cứng 1 product ID. |
| `.longestDuration` | Subscription thời hạn dài nhất. Lifetime (không có period) được tính là `.infinity`. |
| `.custom { products in ... }` | Closure tự quyết định. |

**Ví dụ custom:**
```swift
.custom { products in
    products.first(where: { $0.id.contains("annual") }) ?? products.first
}
```

## Presentation style

``PresentationStyle`` — cách paywall xuất hiện trên màn hình. Per paywall type.

### Sheet (bottom sheet)

```swift
presentation: .sheet(detents: [.medium, .large])
```

Detent hỗ trợ qua ``SheetDetent``: `.medium`, `.large`, `.fraction(0.75)`, `.height(600)`.

### Full screen cover

```swift
presentation: .fullScreenCover
```

Full màn hình, không có gesture drag-to-dismiss. Phù hợp onboarding.

### Popup (centered card)

```swift
presentation: .popup(backdrop: .dim(opacity: 0.6))
```

Card nhỏ ở giữa, backdrop phía sau. Tap backdrop = dismiss.

``BackdropStyle``:
- `.dim(opacity: Double)` — black overlay với độ mờ.
- `.blur` — ultraThinMaterial.
- `.clear` — không backdrop (không khuyến khích — user dễ dismiss nhầm).

## Close button behavior

``CloseButtonBehavior`` — quy định ``PaywallKitUI/PaywallCloseButton`` khi nào xuất hiện.

| Behavior | Use case |
|---|---|
| `.alwaysVisible` | (Default) Paywall thường, user có thể đóng bất cứ lúc nào. |
| `.hidden` | Paywall ép buộc (ví dụ gate bắt buộc mua). Cẩn thận App Store review. |
| `.visibleAfter(N)` | Delay N giây rồi mới cho đóng — giảm misclick và cho user thời gian đọc. Button trong lúc chờ hiện countdown. |

## Reward ads

``RewardAdBehavior`` — bật/tắt button "Watch ad to unlock".

```swift
rewardAd: .enabled(outcome: .grantEphemeral(id: "pro", duration: 300))
```

Xem thêm <doc:RewardAds>.

## Queue

```swift
allowsQueue: true  // default
```

- `true` — nếu có paywall khác đang hiển thị, paywall này được xếp vào queue, show sau khi paywall hiện tại dismiss.
- `false` — gọi `manager.present(_:)` khi đang có paywall sẽ throw ``PaywallError/paywallBusy``.

Dùng `false` cho paywall critical không được chờ; `true` cho paywall tự động trigger.

## Default values

```swift
PaywallConfiguration(
    productMode: .single(productID: "..."),
    presentation: .sheet(),           // default [.large]
    closeButton: .alwaysVisible,
    rewardAd: .disabled,
    allowsQueue: true
)
```

Chỉ `productMode` là bắt buộc, còn lại có default hợp lý.
