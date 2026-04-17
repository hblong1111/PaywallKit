import Foundation
import StoreKit

public protocol PaywallInterceptor: Sendable {
    /// Chạy trước khi paywall xuất hiện. Throw để hủy present — manager sẽ emit lỗi.
    func willPresent(type: PaywallType) async throws

    /// Chạy trước khi gọi StoreKit.purchase. Throw để chặn giao dịch.
    func willPurchase(product: Product) async throws

    /// Chạy trước khi dismiss paywall. Không throw — dùng cho side effect (reward ads, tracking).
    func willDismiss(context: DismissContext) async
}

public extension PaywallInterceptor {
    func willPresent(type: PaywallType) async throws {}
    func willPurchase(product: Product) async throws {}
    func willDismiss(context: DismissContext) async {}
}
