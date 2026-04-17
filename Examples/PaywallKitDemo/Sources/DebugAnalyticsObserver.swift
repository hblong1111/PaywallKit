import Foundation
import PaywallKit

/// Log mọi event ra console — thay thế Firebase/Mixpanel trong demo.
struct DebugAnalyticsObserver: PaywallAnalyticsObserver {
    func observe(_ event: PaywallEvent) async {
        let emoji = emoji(for: event)
        print("\(emoji) [Analytics] \(description(event))")
    }

    private func emoji(for event: PaywallEvent) -> String {
        switch event {
        case .didAppear: "👀"
        case .willDismiss: "⏳"
        case .didDismiss: "👋"
        case .didTapCTA: "👆"
        case .selectionChanged: "🔀"
        case .purchaseStarted: "🛒"
        case .purchaseSucceeded: "✅"
        case .purchaseCancelled: "🚫"
        case .purchaseFailed: "❌"
        case .purchasePending: "⏱️"
        case .restoreStarted: "♻️"
        case .restoreSucceeded: "✅"
        case .restoreFailed: "❌"
        case .offerCodeRedeemed: "🎫"
        case .refundRequested: "💸"
        case .rewardAdRequested: "🎬"
        case .rewardAdEarned: "🏆"
        case .rewardAdFailed: "📵"
        }
    }

    private func description(_ event: PaywallEvent) -> String {
        switch event {
        case .didAppear(let type): "didAppear(\(type.rawValue))"
        case .willDismiss(let ctx): "willDismiss(didPurchase: \(ctx.didPurchase))"
        case .didDismiss(let ctx): "didDismiss(reason: \(ctx.reason))"
        case .didTapCTA(let pid): "didTapCTA(\(pid))"
        case .selectionChanged(let from, let to): "selectionChanged(\(from ?? "nil") → \(to ?? "nil"))"
        case .purchaseStarted(let pid): "purchaseStarted(\(pid))"
        case .purchaseSucceeded(let tx): "purchaseSucceeded(\(tx.productID))"
        case .purchaseCancelled(let pid): "purchaseCancelled(\(pid))"
        case .purchaseFailed(let pid, let err): "purchaseFailed(\(pid), \(err))"
        case .purchasePending(let pid): "purchasePending(\(pid))"
        case .restoreStarted: "restoreStarted"
        case .restoreSucceeded(let ents): "restoreSucceeded(\(ents.count) entitlement)"
        case .restoreFailed(let err): "restoreFailed(\(err))"
        case .offerCodeRedeemed(let code): "offerCodeRedeemed(\(code))"
        case .refundRequested(let pid): "refundRequested(\(pid))"
        case .rewardAdRequested: "rewardAdRequested"
        case .rewardAdEarned(let outcome): "rewardAdEarned(\(outcome.rewardType ?? "-"))"
        case .rewardAdFailed(let err): "rewardAdFailed(\(err))"
        }
    }
}
