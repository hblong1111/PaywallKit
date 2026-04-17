import Foundation
import StoreKit
import PaywallKit

/// In log lifecycle + demo chặn dismiss 1 giây để giả lập show ads.
struct LogInterceptor: PaywallInterceptor {
    func willPresent(type: PaywallType) async throws {
        print("🟢 [Interceptor] willPresent(\(type.rawValue))")
    }

    func willPurchase(product: Product) async throws {
        print("🟡 [Interceptor] willPurchase(\(product.id)) — \(product.displayPrice)")
    }

    func willDismiss(context: DismissContext) async {
        print("🔵 [Interceptor] willDismiss(didPurchase: \(context.didPurchase))")
        guard !context.didPurchase else { return }
        // Giả lập show interstitial 1 giây
        print("   📺 [Interceptor] Pretending to show interstitial ad (1s)...")
        try? await Task.sleep(for: .seconds(1))
    }
}
