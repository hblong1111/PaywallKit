import Foundation
import StoreKit

public enum SelectionStrategy: Sendable {
    case firstAvailable
    case cheapest
    case mostExpensive
    case byID(String)
    case longestDuration
    case custom(@Sendable ([Product]) -> Product?)

    public func pick(from products: [Product]) -> Product? {
        switch self {
        case .firstAvailable:
            return products.first
        case .cheapest:
            return products.min(by: { $0.price < $1.price })
        case .mostExpensive:
            return products.max(by: { $0.price < $1.price })
        case .byID(let id):
            return products.first(where: { $0.id == id })
        case .longestDuration:
            return products.max(by: { Self.durationSeconds($0) < Self.durationSeconds($1) })
        case .custom(let block):
            return block(products)
        }
    }

    private static func durationSeconds(_ product: Product) -> TimeInterval {
        guard let period = product.subscription?.subscriptionPeriod else {
            return .infinity
        }
        let unit: TimeInterval = switch period.unit {
        case .day: 86_400
        case .week: 604_800
        case .month: 2_628_000
        case .year: 31_536_000
        @unknown default: 0
        }
        return unit * TimeInterval(period.value)
    }
}
