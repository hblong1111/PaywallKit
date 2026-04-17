import Foundation

public struct RewardOutcome: Sendable, Equatable {
    public let earned: Bool
    public let rewardType: String?
    public let rewardAmount: Double?

    public init(earned: Bool, rewardType: String? = nil, rewardAmount: Double? = nil) {
        self.earned = earned
        self.rewardType = rewardType
        self.rewardAmount = rewardAmount
    }

    public static let notEarned = RewardOutcome(earned: false)
}
