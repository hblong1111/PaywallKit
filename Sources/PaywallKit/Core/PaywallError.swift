import Foundation

public enum PaywallError: Error, Sendable, Equatable {
    case network(message: String)
    case storeKit(code: Int, message: String)
    case productNotFound(id: String)
    case verificationFailed(reason: String)
    case userCancelled
    case pendingApproval
    case interceptorBlocked(reason: String)
    case adapter(providerName: String, message: String)
    case paywallBusy
    case rewardAdNotReady
    case unknown(message: String)

    public init(_ error: any Error) {
        if let paywall = error as? PaywallError {
            self = paywall
        } else {
            self = .unknown(message: String(describing: error))
        }
    }
}

extension PaywallError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .network(let m): return "Network error: \(m)"
        case .storeKit(let c, let m): return "StoreKit error (\(c)): \(m)"
        case .productNotFound(let id): return "Product not found: \(id)"
        case .verificationFailed(let r): return "Verification failed: \(r)"
        case .userCancelled: return "User cancelled purchase"
        case .pendingApproval: return "Purchase pending approval"
        case .interceptorBlocked(let r): return "Blocked by interceptor: \(r)"
        case .adapter(let p, let m): return "[\(p)] \(m)"
        case .paywallBusy: return "Another paywall is currently presented"
        case .rewardAdNotReady: return "Reward ad is not ready"
        case .unknown(let m): return m
        }
    }
}
