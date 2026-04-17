import Foundation
import StoreKit

public struct PurchaseOptions: Sendable {
    public enum FinishStrategy: Sendable {
        case auto
        case manual
    }
    public var finishStrategy: FinishStrategy
    public var interceptorTimeout: TimeInterval

    public init(finishStrategy: FinishStrategy = .auto, interceptorTimeout: TimeInterval = 5) {
        self.finishStrategy = finishStrategy
        self.interceptorTimeout = interceptorTimeout
    }
}

public struct PurchaseResult: Sendable {
    public enum Outcome: Sendable {
        case success(VerifiedTransaction)
        case pending
        case cancelled
    }
    public let outcome: Outcome
    public let productID: String
}

@MainActor
final class PurchaseCoordinator {
    let provider: any ProductProvider
    let interceptors: [any PaywallInterceptor]
    let options: PurchaseOptions

    init(
        provider: any ProductProvider,
        interceptors: [any PaywallInterceptor],
        options: PurchaseOptions
    ) {
        self.provider = provider
        self.interceptors = interceptors
        self.options = options
    }

    func purchase(_ product: Product) async throws -> PurchaseResult {
        for interceptor in interceptors {
            do {
                try await withTimeout(seconds: options.interceptorTimeout) {
                    try await interceptor.willPurchase(product: product)
                }
            } catch is TimeoutError {
                throw PaywallError.interceptorBlocked(reason: "interceptor timeout")
            } catch let error as PaywallError {
                throw error
            } catch {
                throw PaywallError.interceptorBlocked(reason: error.localizedDescription)
            }
        }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch let error as StoreKitError {
            throw PaywallError.storeKit(code: 0, message: String(describing: error))
        } catch let error as Product.PurchaseError {
            throw PaywallError.storeKit(code: 0, message: String(describing: error))
        } catch {
            throw PaywallError.storeKit(
                code: (error as NSError).code,
                message: error.localizedDescription
            )
        }

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                let verified = VerifiedTransaction(transaction, jws: verification.jwsRepresentation)
                if options.finishStrategy == .auto {
                    await transaction.finish()
                }
                return PurchaseResult(outcome: .success(verified), productID: product.id)
            case .unverified(_, let error):
                throw PaywallError.verificationFailed(reason: error.localizedDescription)
            }
        case .userCancelled:
            return PurchaseResult(outcome: .cancelled, productID: product.id)
        case .pending:
            return PurchaseResult(outcome: .pending, productID: product.id)
        @unknown default:
            throw PaywallError.unknown(message: "Unknown purchase result")
        }
    }

    func restore() async throws -> Set<Entitlement> {
        try await provider.restorePurchases()
    }
}
