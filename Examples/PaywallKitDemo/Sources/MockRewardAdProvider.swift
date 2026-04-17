import Foundation
import PaywallKit

/// Fake reward ads adapter dùng cho demo — không gọi AdMob thật.
/// Giả lập: delay 2s → earned.
final class MockRewardAdProvider: RewardAdProvider {
    func isReady() async -> Bool {
        true
    }

    func show() async throws -> RewardOutcome {
        try await Task.sleep(for: .seconds(2))
        return RewardOutcome(earned: true, rewardType: "demo_reward", rewardAmount: 1)
    }
}
