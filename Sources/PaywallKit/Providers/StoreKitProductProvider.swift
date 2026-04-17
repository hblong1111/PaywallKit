import Foundation
import StoreKit

public final class StoreKitProductProvider: ProductProvider {
    public let providerName = "StoreKit"
    public let productIDMap: [PaywallType: [String]]

    public let transactionUpdates: AsyncStream<VerifiedTransaction>
    private let continuation: AsyncStream<VerifiedTransaction>.Continuation
    private let listenTask: Task<Void, Never>

    public init(productIDMap: [PaywallType: [String]]) {
        self.productIDMap = productIDMap
        let (stream, continuation) = AsyncStream<VerifiedTransaction>.makeStream()
        self.transactionUpdates = stream
        self.continuation = continuation

        self.listenTask = Task {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    continuation.yield(VerifiedTransaction(transaction, jws: update.jwsRepresentation))
                }
            }
        }
    }

    deinit {
        listenTask.cancel()
        continuation.finish()
    }

    public func products(for type: PaywallType, mode: ProductMode) async throws -> [Product] {
        let ids: [String] = switch mode {
        case .single(let id): [id]
        case .multi:
            productIDMap[type] ?? []
        }
        guard !ids.isEmpty else {
            throw PaywallError.productNotFound(id: type.rawValue)
        }
        do {
            let products = try await Product.products(for: ids)
            guard !products.isEmpty else {
                throw PaywallError.productNotFound(id: ids.joined(separator: ","))
            }
            return products
        } catch let error as PaywallError {
            throw error
        } catch {
            throw PaywallError.storeKit(
                code: (error as NSError).code,
                message: error.localizedDescription
            )
        }
    }

    public func refreshEntitlements() async throws -> Set<Entitlement> {
        var result: Set<Entitlement> = []
        for await item in Transaction.currentEntitlements {
            switch item {
            case .verified(let transaction):
                result.insert(Entitlement(
                    id: Entitlement.ID(transaction.productID),
                    productID: transaction.productID,
                    expiresAt: transaction.expirationDate,
                    isEphemeral: false,
                    source: .purchase
                ))
            case .unverified(_, let error):
                throw PaywallError.verificationFailed(reason: error.localizedDescription)
            }
        }
        return result
    }

    public func restorePurchases() async throws -> Set<Entitlement> {
        do {
            try await AppStore.sync()
        } catch {
            throw PaywallError.storeKit(
                code: (error as NSError).code,
                message: error.localizedDescription
            )
        }
        return try await refreshEntitlements()
    }
}
