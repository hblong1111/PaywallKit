import SwiftUI
import PaywallKit

public struct PaywallRestoreButton<Label: View>: View {
    @Environment(PaywallManager.self) private var manager
    private let label: () -> Label

    public init(@ViewBuilder label: @escaping () -> Label) {
        self.label = label
    }

    public var body: some View {
        Button {
            Task { try? await manager.restore() }
        } label: {
            label()
        }
        .disabled(manager.isLoading)
    }
}
