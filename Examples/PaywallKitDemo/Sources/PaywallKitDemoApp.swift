import SwiftUI
import PaywallKit
import PaywallKitUI

@main
struct PaywallKitDemoApp: App {
    @State private var manager: PaywallManager
    @State private var registry: PaywallRegistry

    init() {
        let provider = StoreKitProductProvider(productIDMap: [
            .onboarding: [
                "com.paywallkit.demo.pro.monthly",
                "com.paywallkit.demo.pro.yearly",
                "com.paywallkit.demo.pro.lifetime",
            ],
            .featureGate: [
                "com.paywallkit.demo.pro.yearly",
            ],
            .settings: [
                "com.paywallkit.demo.pro.monthly",
                "com.paywallkit.demo.pro.yearly",
            ],
        ])

        let manager = PaywallManager(
            provider: provider,
            interceptors: [LogInterceptor()],
            analytics: [DebugAnalyticsObserver()],
            rewardAdProvider: MockRewardAdProvider(),
            entitlementPersistence: InMemoryEntitlementPersistence()
        )

        _manager = State(initialValue: manager)
        _registry = State(initialValue: PaywallRegistry(manager: manager))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(manager)
                .paywallPresenter(registry: registry)
                .task { registerPaywalls() }
        }
    }

    @MainActor
    private func registerPaywalls() {
        // 1) Onboarding — multi product, full screen, close sau 3s
        registry.register(
            .onboarding,
            config: PaywallConfiguration(
                productMode: .multi(strategy: .mostExpensive),
                presentation: .fullScreenCover,
                closeButton: .visibleAfter(3),
                rewardAd: .enabled(outcome: .grantEphemeral(id: "pro", duration: 120)),
                allowsQueue: false
            )
        ) {
            OnboardingPaywallView()
        }

        // 2) Feature gate — single product, popup nhỏ
        registry.register(
            .featureGate,
            config: PaywallConfiguration(
                productMode: .single(productID: "com.paywallkit.demo.pro.yearly"),
                presentation: .popup(backdrop: .dim(opacity: 0.6)),
                closeButton: .alwaysVisible,
                rewardAd: .disabled,
                allowsQueue: true
            )
        ) {
            FeatureGatePaywallView()
        }

        // 3) Settings — multi product, sheet medium
        registry.register(
            .settings,
            config: PaywallConfiguration(
                productMode: .multi(strategy: .cheapest),
                presentation: .sheet(detents: [.medium, .large]),
                closeButton: .alwaysVisible,
                rewardAd: .disabled,
                allowsQueue: true
            )
        ) {
            SettingsPaywallView()
        }
    }
}
