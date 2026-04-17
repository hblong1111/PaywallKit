import SwiftUI
import PaywallKit

public struct PaywallLoadingIndicator: View {
    @Environment(PaywallManager.self) private var manager

    public init() {}

    public var body: some View {
        if manager.isLoading {
            ProgressView()
        }
    }
}
