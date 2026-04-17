import Foundation

public enum ProductMode: Sendable {
    case single(productID: String)
    case multi(strategy: SelectionStrategy)

    public var isSingle: Bool {
        if case .single = self { return true }
        return false
    }
}
