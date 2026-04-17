import SwiftUI
import PaywallKit
import PaywallKitUI

struct SettingsPaywallView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.yellow)

                    Text("Go Premium")
                        .font(.title.bold())

                    Text("Pick the plan that fits")
                        .foregroundStyle(.secondary)

                    PaywallProductPicker { product, isSelected in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.displayName).bold()
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(product.displayPrice).bold()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.08))
                        )
                    }

                    PaywallBuyButton {
                        Text("Subscribe")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.yellow, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.black)
                    }

                    PaywallRestoreButton {
                        Text("Restore").font(.footnote)
                    }

                    PaywallErrorBanner()
                }
                .padding()
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PaywallCloseButton {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
