# Bắt đầu với PaywallKit

Tích hợp PaywallKit vào app iOS 17+ trong 10 phút.

## Overview

Bài này đi từ 0 → show được paywall đầu tiên với 1 product, dùng StoreKit 2 native.

## Yêu cầu

- iOS 17+ (do dùng `@Observable`).
- Swift tools 6.2+, Xcode 16+.
- Đã tạo product/subscription trong App Store Connect hoặc file `.storekit` để test local.

## 1. Thêm dependency

Trong `Package.swift` của app:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/PaywallKit.git", from: "0.1.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "PaywallKit", package: "PaywallKit"),
            .product(name: "PaywallKitUI", package: "PaywallKit"),
        ]
    )
]
```

Chỉ import `PaywallKitUI` nếu bạn muốn dùng presenter layer của lib; nếu tự viết layer SwiftUI thì chỉ cần `PaywallKit`.

## 2. Định nghĩa `PaywallType`

`PaywallType` là identifier do app quyết định. Lib chỉ dùng giá trị để lookup config:

```swift
import PaywallKit

extension PaywallType {
    static let onboarding: PaywallType = "onboarding"
    static let featureGate: PaywallType = "feature_gate"
}
```

## 3. Khởi tạo `PaywallManager`

Nơi khởi tạo: ở `App` struct, scope `@State` hoặc singleton riêng của app.

```swift
import SwiftUI
import PaywallKit
import PaywallKitUI

@main
struct MyApp: App {
    @State private var manager: PaywallManager
    @State private var registry: PaywallRegistry

    init() {
        let provider = StoreKitProductProvider(productIDMap: [
            .onboarding: ["com.myapp.pro.monthly", "com.myapp.pro.yearly"],
            .featureGate: ["com.myapp.pro.yearly"],
        ])
        let manager = PaywallManager(provider: provider)
        _manager = State(initialValue: manager)
        _registry = State(initialValue: PaywallRegistry(manager: manager))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .paywallPresenter(registry: registry)
                .environment(manager)
                .task { await registerPaywalls() }
        }
    }

    @MainActor
    private func registerPaywalls() {
        registry.register(
            .onboarding,
            config: PaywallConfiguration(
                productMode: .multi(strategy: .mostExpensive),
                presentation: .fullScreenCover,
                closeButton: .visibleAfter(3)
            )
        ) {
            OnboardingPaywallView()
        }

        registry.register(
            .featureGate,
            config: PaywallConfiguration(
                productMode: .single(productID: "com.myapp.pro.yearly"),
                presentation: .popup()
            )
        ) {
            FeatureGatePaywallView()
        }
    }
}
```

> **Quan trọng — thứ tự modifier:** `.paywallPresenter(...)` phải nằm TRƯỚC `.environment(manager)`. Presenter modifier đọc `PaywallManager` từ environment; nếu `.environment(manager)` đặt phía trong, modifier sẽ không thấy được và app crash với *"No Observable object of type PaywallManager found."*

## 4. Vẽ UI paywall

```swift
import SwiftUI
import PaywallKit
import PaywallKitUI

struct OnboardingPaywallView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        VStack(spacing: 16) {
            Text("Unlock Pro")
                .font(.largeTitle.bold())

            PaywallProductPicker { product, isSelected in
                HStack {
                    VStack(alignment: .leading) {
                        Text(product.displayName).bold()
                        Text(product.description).font(.footnote)
                    }
                    Spacer()
                    Text(product.displayPrice)
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : .gray, lineWidth: 2)
                )
            }

            PaywallBuyButton {
                Text("Continue")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }

            HStack {
                PaywallRestoreButton { Text("Restore") }
                Spacer()
                PaywallCloseButton { Image(systemName: "xmark") }
            }

            PaywallLoadingIndicator()
            PaywallErrorBanner()
        }
        .padding()
    }
}
```

## 5. Trigger paywall

Ở bất cứ đâu trong app:

```swift
Button("Upgrade") {
    Task {
        try? await manager.present(.featureGate)
    }
}
```

Lib sẽ:
1. Chạy interceptor `willPresent` (nếu có).
2. Fetch product qua cache → provider.
3. Tính default selection theo strategy.
4. Show theo `PresentationStyle` đã config.

## 6. Gate feature theo entitlement

```swift
struct ProFeatureView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        if manager.entitlements.has("pro") {
            FullFeatureView()
        } else {
            Button("Unlock Pro") {
                Task { try? await manager.present(.featureGate) }
            }
        }
    }
}
```

## Tiếp theo

- <doc:Configuration> — tuỳ chỉnh product mode, selection strategy, close button.
- <doc:CustomUI> — vẽ paywall hoàn toàn custom, bỏ qua built-in button.
- <doc:HandlingEvents> — subscribe event stream để forward analytics.
- <doc:RewardAds> — cho user xem reward ads để unlock tạm thời.
