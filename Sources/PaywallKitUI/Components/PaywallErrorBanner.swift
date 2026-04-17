import SwiftUI
import PaywallKit

public struct PaywallErrorBanner: View {
    @Environment(PaywallManager.self) private var manager

    public init() {}

    public var body: some View {
        if let message = manager.lastError?.errorDescription {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(.red.opacity(0.1))
                )
                .transition(.opacity)
        }
    }
}
