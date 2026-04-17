import Foundation

public enum PaywallEvent: Sendable {
    case didAppear(type: PaywallType)
    case willDismiss(context: DismissContext)
    case didDismiss(context: DismissContext)

    case didTapCTA(productID: String)
    case selectionChanged(from: String?, to: String?)

    case purchaseStarted(productID: String)
    case purchaseSucceeded(transaction: VerifiedTransaction)
    case purchaseCancelled(productID: String)
    case purchaseFailed(productID: String, error: PaywallError)
    case purchasePending(productID: String)

    case restoreStarted
    case restoreSucceeded(entitlements: Set<Entitlement>)
    case restoreFailed(error: PaywallError)

    case offerCodeRedeemed(code: String)
    case refundRequested(productID: String)

    case rewardAdRequested
    case rewardAdEarned(outcome: RewardOutcome)
    case rewardAdFailed(error: PaywallError)
}
