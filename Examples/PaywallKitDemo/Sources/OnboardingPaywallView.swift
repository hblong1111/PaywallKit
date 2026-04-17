import SwiftUI
import StoreKit
import PaywallKit
import PaywallKitUI

struct OnboardingPaywallView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    benefits
                    productPicker
                    PaywallBuyButton {
                        Text(buyButtonTitle)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    PaywallRewardAdButton {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                            Text("Watch ad — 2 min free Pro")
                        }
                        .font(.footnote.weight(.medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(.purple.opacity(0.15), in: Capsule())
                        .foregroundStyle(.purple)
                    }
                    HStack {
                        PaywallRestoreButton { Text("Restore").font(.footnote) }
                        Spacer()
                        Text("Terms · Privacy").font(.footnote).foregroundStyle(.secondary)
                    }
                    PaywallErrorBanner()
                }
                .padding()
            }
            PaywallLoadingIndicator()
        }
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                Text("Unlock Pro")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Get full access to every feature")
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            )

            PaywallCloseButton {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Circle().fill(.black.opacity(0.25)))
            }
            .padding()
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(["Unlimited exports", "Pro filters", "No ads", "Priority support"], id: \.self) { text in
                Label(text, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.primary)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var productPicker: some View {
        PaywallProductPicker { product, isSelected in
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName).bold()
                    Text(periodLabel(for: product))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .bold()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
    }

    private var buyButtonTitle: String {
        guard let selected = manager.selection.selected else { return "Continue" }
        return "Continue with \(selected.displayName)"
    }

    private func periodLabel(for product: Product) -> String {
        guard let sub = product.subscription else { return "Lifetime" }
        return "billed \(sub.subscriptionPeriod.formatted())"
    }
}

private extension Product.SubscriptionPeriod {
    func formatted() -> String {
        let unit = switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
        return value > 1 ? "every \(value) \(unit)s" : unit + "ly"
    }
}
