# Vẽ UI paywall tùy chỉnh

App tự thiết kế paywall view; PaywallKit chỉ cung cấp state và action. 

## Overview

`PaywallManager` đã chuẩn bị sẵn:
- Product list + selection state.
- Loading / error state.
- Entitlement.
- Hàm buy / restore / dismiss / show reward ads.

App chỉ cần:
1. Đọc state qua `@Environment(PaywallManager.self)`.
2. Render UI theo ý muốn.
3. Gọi action khi user tương tác.

## Anatomy

```swift
struct MyPaywallView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        VStack {
            // 1) Header do app vẽ, lấy text từ product list
            header

            // 2) Product list + selection
            productList

            // 3) CTA buttons (app vẽ, gọi manager action)
            ctaButtons

            // 4) Status (loading, error) — có thể dùng built-in hoặc tự vẽ
            PaywallLoadingIndicator()
            PaywallErrorBanner()
        }
    }
}
```

## Đọc state

### Product list

```swift
let products = manager.selection.available
let selected = manager.selection.selected
```

Khi provider fetch xong, `available` được set và `selected` được tính theo strategy. Mọi thay đổi trigger re-render SwiftUI vì ``PaywallSelection`` là `@Observable`.

### Single-product helper

```swift
if manager.selection.isSingleProduct {
    SingleProductCard(product: manager.selection.available.first!)
} else {
    MultiProductPicker(products: manager.selection.available)
}
```

### Loading

```swift
if manager.isLoading {
    ProgressView("Loading...")
}
```

### Error

```swift
if let error = manager.lastError {
    Text(error.errorDescription ?? "")
        .foregroundStyle(.red)
}
```

### Entitlement (để gate feature ngoài paywall)

```swift
if manager.entitlements.has("pro") {
    ProContent()
}
```

## Action

### Mua product đang chọn

```swift
Button("Buy") {
    Task {
        try? await manager.purchaseSelected()
    }
}
.disabled(manager.selection.selected == nil || manager.isLoading)
```

### Mua product cụ thể (bỏ qua selection)

```swift
Button("Buy yearly") {
    Task {
        guard let product = manager.selection.available.first(where: { $0.id == "yearly" }) else { return }
        try? await manager.purchase(product)
    }
}
```

### Chọn product (radio/tab)

```swift
ForEach(manager.selection.available) { product in
    Button {
        manager.selection.selectByID(product.id)
    } label: {
        ProductCard(product: product, selected: manager.selection.selected?.id == product.id)
    }
}
```

### Restore

```swift
Button("Restore purchases") {
    Task { try? await manager.restore() }
}
```

### Close

```swift
Button("Close") {
    Task { await manager.dismiss(reason: .user) }
}
```

## Bỏ qua PaywallKitUI

Bạn hoàn toàn có thể KHÔNG import `PaywallKitUI` và tự dựng `.sheet(isPresented:)` xoay quanh `manager.presentedType`:

```swift
struct RootView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        ContentView()
            .sheet(
                isPresented: Binding(
                    get: { manager.presentedType != nil },
                    set: { if !$0 { Task { await manager.dismiss() } } }
                )
            ) {
                if let type = manager.presentedType {
                    myPaywallView(for: type)
                }
            }
    }
}
```

`PaywallKitUI` chỉ là tiện lợi — không phải ràng buộc.

## Preview

Preview paywall view không cần StoreKit thật:

```swift
#Preview {
    OnboardingPaywallView()
        .environment(PaywallManager.preview())
}
```

Xem <doc:Testing> cho chi tiết về mock provider.
