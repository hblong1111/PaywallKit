import SwiftUI
import PaywallKit

public struct PaywallCloseButton<Label: View>: View {
    @Environment(PaywallManager.self) private var manager
    private let label: () -> Label
    @State private var visible: Bool = true
    @State private var remaining: Int = 0

    public init(@ViewBuilder label: @escaping () -> Label) {
        self.label = label
    }

    public var body: some View {
        Group {
            if visible {
                Button {
                    Task { await manager.dismiss(reason: .user) }
                } label: {
                    label()
                }
            } else if remaining > 0 {
                Text("\(remaining)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.thinMaterial))
                    .accessibilityLabel("Close available in \(remaining) seconds")
            }
        }
        .onAppear { apply(manager.currentConfiguration?.closeButton) }
        .onChange(of: manager.currentConfiguration?.closeButton) { _, new in
            apply(new)
        }
    }

    private func apply(_ behavior: CloseButtonBehavior?) {
        switch behavior {
        case .alwaysVisible, .none:
            visible = true
            remaining = 0
        case .hidden:
            visible = false
            remaining = 0
        case .visibleAfter(let delay):
            visible = false
            remaining = Int(delay.rounded(.up))
            Task { @MainActor in
                while remaining > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    remaining -= 1
                }
                visible = true
            }
        }
    }
}
