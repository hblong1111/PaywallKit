import Foundation

public struct PaywallConfiguration: Sendable {
    public let productMode: ProductMode
    public let presentation: PresentationStyle
    public let closeButton: CloseButtonBehavior
    public let rewardAd: RewardAdBehavior
    public let allowsQueue: Bool

    public init(
        productMode: ProductMode,
        presentation: PresentationStyle = .sheet(),
        closeButton: CloseButtonBehavior = .alwaysVisible,
        rewardAd: RewardAdBehavior = .disabled,
        allowsQueue: Bool = true
    ) {
        self.productMode = productMode
        self.presentation = presentation
        self.closeButton = closeButton
        self.rewardAd = rewardAd
        self.allowsQueue = allowsQueue
    }
}
