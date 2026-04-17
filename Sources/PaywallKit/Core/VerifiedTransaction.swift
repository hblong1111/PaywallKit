import Foundation
import StoreKit

public struct VerifiedTransaction: Sendable, Identifiable {
    public let id: UInt64
    public let originalID: UInt64
    public let productID: String
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let isAutoRenewable: Bool
    public let jwsRepresentation: String
    public let rawTransaction: Transaction

    public init(_ transaction: Transaction, jws: String) {
        self.id = transaction.id
        self.originalID = transaction.originalID
        self.productID = transaction.productID
        self.purchaseDate = transaction.purchaseDate
        self.expirationDate = transaction.expirationDate
        self.isAutoRenewable = transaction.productType == .autoRenewable
        self.jwsRepresentation = jws
        self.rawTransaction = transaction
    }

    public func finish() async {
        await rawTransaction.finish()
    }
}
