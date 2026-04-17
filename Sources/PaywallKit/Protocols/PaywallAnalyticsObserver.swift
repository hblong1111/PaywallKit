import Foundation

public protocol PaywallAnalyticsObserver: Sendable {
    /// Nhận mọi PaywallEvent. Chạy fire-and-forget, lỗi isolated — không block main.
    func observe(_ event: PaywallEvent) async
}
