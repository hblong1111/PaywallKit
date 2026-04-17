# Các kiểu presentation

Sheet, full screen, popup — và cách chọn đúng kiểu cho từng use case.

## Sheet (bottom sheet)

```swift
presentation: .sheet(detents: [.medium, .large])
```

**Use case:** Settings paywall, upsell từ trong feature, paywall contextual.

**Đặc điểm:**
- User drag xuống để dismiss.
- Có thể có multiple detent.
- Paywall content bị co chiều cao theo detent.

**Detents:**
```swift
.sheet(detents: [.medium])                   // nửa màn hình
.sheet(detents: [.large])                    // gần hết màn hình
.sheet(detents: [.medium, .large])           // user kéo được 2 mức
.sheet(detents: [.fraction(0.75)])           // 75% chiều cao
.sheet(detents: [.height(480)])              // chiều cao cố định
```

## Full screen cover

```swift
presentation: .fullScreenCover
```

**Use case:** Onboarding paywall, paywall "first-run", paywall lock app.

**Đặc điểm:**
- Không có gesture dismiss.
- Chiếm toàn màn hình.
- Bắt buộc user tap close button (nếu có) hoặc mua.

**Kết hợp với `closeButton: .hidden`:**

```swift
PaywallConfiguration(
    productMode: .multi(strategy: .mostExpensive),
    presentation: .fullScreenCover,
    closeButton: .hidden
)
```

> ⚠️ Paywall không có close button vi phạm App Store Review Guidelines (4.2.3, 3.1.2). Dùng cẩn trọng.

## Popup (centered card)

```swift
presentation: .popup(backdrop: .dim(opacity: 0.5))
```

**Use case:** Upsell nhanh, feature-gate trong app, "bạn đã dùng hết lượt free".

**Đặc điểm:**
- Card nhỏ ở giữa màn hình.
- Backdrop phía sau (dim / blur / clear).
- Tap backdrop = dismiss (equivalent `manager.dismiss(reason: .user)`).
- Scale + fade animation vào/ra.

**Backdrop:**
```swift
.popup(backdrop: .dim(opacity: 0.5))    // mặc định
.popup(backdrop: .blur)                  // blur (ultraThinMaterial)
.popup(backdrop: .clear)                 // không có — không khuyến khích
```

## Chọn style nào

| Use case | Style đề xuất |
|---|---|
| Onboarding lần đầu, 2-3 option | `.fullScreenCover` |
| Upsell sau khi dùng feature free | `.sheet(detents: [.medium])` |
| "Bạn đã hết lượt, nâng cấp?" | `.popup()` |
| Settings → "Get Premium" | `.sheet(detents: [.large])` |
| Trial expired, buộc chọn plan | `.fullScreenCover` + `closeButton: .visibleAfter(5)` |

## So sánh cùng 1 paywall view với 3 style

Cùng `OnboardingPaywallView()`, register 3 lần với 3 `PaywallType` khác nhau:

```swift
registry.register(.onboarding, config: .init(productMode: .multi(strategy: .mostExpensive), presentation: .fullScreenCover)) { OnboardingPaywallView() }
registry.register(.settings,   config: .init(productMode: .multi(strategy: .mostExpensive), presentation: .sheet())) { OnboardingPaywallView() }
registry.register(.quick,      config: .init(productMode: .single(productID: "yearly"), presentation: .popup())) { OnboardingPaywallView() }
```

View không cần biết mình đang hiển thị ở đâu.

## Custom transition

Hiện tại lib chưa ship ``PresentationStyle/custom``. Nếu cần animation riêng (ví dụ zoom từ button source), tạm thời không dùng `.paywallPresenter()` — tự handle `manager.presentedType` trong view root:

```swift
ZStack {
    ContentView()
    if manager.presentedType == .onboarding {
        OnboardingPaywallView()
            .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity),
                                     removal: .opacity))
    }
}
.animation(.spring, value: manager.presentedType)
```

Custom transition sẽ được thêm vào ``PresentationStyle`` ở phiên bản sau.
