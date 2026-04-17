import Foundation
import SwiftUI
import PaywallKit

@MainActor
public final class PaywallRegistry {
    private weak var manager: PaywallManager?
    private var builders: [PaywallType: @MainActor () -> AnyView] = [:]

    public init(manager: PaywallManager) {
        self.manager = manager
    }

    public func register<V: View>(
        _ type: PaywallType,
        config: PaywallConfiguration,
        @ViewBuilder view: @escaping @MainActor () -> V
    ) {
        manager?.register(type, config: config)
        builders[type] = { AnyView(view()) }
    }

    @MainActor
    func makeView(for type: PaywallType) -> AnyView? {
        builders[type]?()
    }
}
