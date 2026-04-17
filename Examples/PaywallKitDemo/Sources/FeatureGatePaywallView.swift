import SwiftUI
import PaywallKit
import PaywallKitUI

struct FeatureGatePaywallView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                PaywallCloseButton {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
            }

            Image(systemName: "wand.and.stars")
                .font(.system(size: 44))
                .foregroundStyle(.purple)

            Text("Unlock magic filter")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if let product = manager.selection.selected {
                VStack(spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title.bold())
                    Text(product.displayName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
            }

            PaywallBuyButton {
                Text("Continue")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }

            PaywallRestoreButton {
                Text("Already subscribed? Restore")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            PaywallErrorBanner()
        }
        .frame(maxWidth: 320)
    }
}
