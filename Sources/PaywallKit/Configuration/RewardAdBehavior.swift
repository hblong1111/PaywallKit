import Foundation

public enum RewardAdBehavior: Sendable {
    case disabled
    case enabled(outcome: RewardOutcomeAction)
}

public enum RewardOutcomeAction: Sendable {
    /// Cấp entitlement tạm thời sau khi user xem hết reward ads.
    case grantEphemeral(id: Entitlement.ID, duration: TimeInterval)

    /// Đổi selection hiện tại sang product có ID chỉ định.
    case switchSelection(toProductID: String)

    /// App tự quyết định kết quả dựa trên `RewardOutcome`.
    /// Closure chạy trên background; PaywallManager apply result trên MainActor.
    case custom(@Sendable (RewardOutcome) async -> CustomRewardResult)
}

public enum CustomRewardResult: Sendable {
    case grantEphemeral(id: Entitlement.ID, duration: TimeInterval)
    case switchSelection(toProductID: String)
    case dismissPaywall
    case noop
}
