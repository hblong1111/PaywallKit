import Foundation

public protocol RewardAdProvider: Sendable {
    /// Có ad sẵn sàng show không? Lib dùng để ẩn/hiện `PaywallRewardAdButton`.
    func isReady() async -> Bool

    /// Show reward ad. Throw nếu không load được; trả về outcome (earned hoặc không).
    func show() async throws -> RewardOutcome
}
