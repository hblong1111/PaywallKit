import Foundation
import StoreKit

@MainActor
@Observable
public final class PaywallSelection {
    public private(set) var available: [Product] = []
    public var selected: Product?
    public var selectedOffer: Product.SubscriptionOffer?
    public var strategy: SelectionStrategy = .firstAvailable

    public var isSingleProduct: Bool { available.count == 1 }

    public init() {}

    /// Cập nhật product list + tính lại selection theo strategy.
    /// `forcedID` (nếu có) ép selection sang product có id chỉ định (ưu tiên cao hơn strategy).
    public func update(available: [Product], strategy: SelectionStrategy? = nil, forcedID: String? = nil) {
        self.available = available
        if let strategy {
            self.strategy = strategy
        }
        if let forcedID, let match = available.first(where: { $0.id == forcedID }) {
            self.selected = match
        } else if let current = selected, available.contains(where: { $0.id == current.id }) {
            // giữ selection cũ nếu vẫn còn hợp lệ
        } else {
            self.selected = self.strategy.pick(from: available)
        }
        self.selectedOffer = nil
    }

    public func selectByID(_ id: String) {
        guard let match = available.first(where: { $0.id == id }) else { return }
        selected = match
        selectedOffer = nil
    }

    public func clear() {
        available = []
        selected = nil
        selectedOffer = nil
    }
}
