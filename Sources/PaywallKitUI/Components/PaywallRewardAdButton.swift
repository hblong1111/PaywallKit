import SwiftUI
import PaywallKit

public struct PaywallRewardAdButton<Label: View>: View {
    @Environment(PaywallManager.self) private var manager
    private let label: () -> Label
    @State private var ready: Bool = false

    public init(@ViewBuilder label: @escaping () -> Label) {
        self.label = label
    }

    public var body: some View {
        Group {
            if shouldShow && ready {
                Button {
                    Task { await manager.showRewardAd() }
                } label: {
                    label()
                }
                .disabled(manager.isLoading)
            }
        }
        .task(id: manager.presentedType?.rawValue ?? "") {
            ready = await manager.isRewardAdReady()
        }
    }

    private var shouldShow: Bool {
        guard let config = manager.currentConfiguration else { return false }
        if case .enabled = config.rewardAd { return true }
        return false
    }
}
