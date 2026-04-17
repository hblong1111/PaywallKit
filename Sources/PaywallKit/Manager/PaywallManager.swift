import Foundation
import Observation
import StoreKit

@MainActor
@Observable
public final class PaywallManager {
    public private(set) var presentedType: PaywallType?
    public private(set) var currentConfiguration: PaywallConfiguration?
    public private(set) var isLoading: Bool = false
    public private(set) var lastError: PaywallError?
    public let selection: PaywallSelection
    public let entitlements: EntitlementStore

    public let events: AsyncStream<PaywallEvent>

    @ObservationIgnored private let provider: any ProductProvider
    @ObservationIgnored private let cache: any PaywallCache
    @ObservationIgnored private let interceptors: [any PaywallInterceptor]
    @ObservationIgnored private let analytics: [any PaywallAnalyticsObserver]
    @ObservationIgnored private let rewardAdProvider: (any RewardAdProvider)?
    @ObservationIgnored private let coordinator: PurchaseCoordinator
    @ObservationIgnored private let purchaseOptions: PurchaseOptions

    @ObservationIgnored private var configs: [PaywallType: PaywallConfiguration] = [:]
    @ObservationIgnored private var queue: [QueuedPaywall] = []
    @ObservationIgnored private let eventContinuation: AsyncStream<PaywallEvent>.Continuation
    @ObservationIgnored private var transactionListenerTask: Task<Void, Never>?

    public init(
        provider: any ProductProvider,
        cache: any PaywallCache = InMemoryPaywallCache(),
        interceptors: [any PaywallInterceptor] = [],
        analytics: [any PaywallAnalyticsObserver] = [],
        rewardAdProvider: (any RewardAdProvider)? = nil,
        entitlementPersistence: any EntitlementPersistence = KeychainEntitlementPersistence(),
        purchaseOptions: PurchaseOptions = .init()
    ) {
        self.provider = provider
        self.cache = cache
        self.interceptors = interceptors
        self.analytics = analytics
        self.rewardAdProvider = rewardAdProvider
        self.purchaseOptions = purchaseOptions
        self.selection = PaywallSelection()
        self.entitlements = EntitlementStore(persistence: entitlementPersistence)
        self.coordinator = PurchaseCoordinator(
            provider: provider,
            interceptors: interceptors,
            options: purchaseOptions
        )

        let (stream, continuation) = AsyncStream<PaywallEvent>.makeStream(bufferingPolicy: .bufferingNewest(32))
        self.events = stream
        self.eventContinuation = continuation

        startTransactionListener()
    }

    deinit {
        transactionListenerTask?.cancel()
        eventContinuation.finish()
    }

    // MARK: - Registration

    public func register(_ type: PaywallType, config: PaywallConfiguration) {
        configs[type] = config
    }

    public func configuration(for type: PaywallType) -> PaywallConfiguration? {
        configs[type]
    }

    // MARK: - Present / Dismiss

    public func present(_ type: PaywallType) async throws {
        guard let config = configs[type] else {
            throw PaywallError.productNotFound(id: type.rawValue)
        }

        if presentedType != nil {
            if config.allowsQueue {
                queue.append(QueuedPaywall(type: type, config: config))
                return
            } else {
                throw PaywallError.paywallBusy
            }
        }

        for interceptor in interceptors {
            do {
                try await withTimeout(seconds: purchaseOptions.interceptorTimeout) {
                    try await interceptor.willPresent(type: type)
                }
            } catch is TimeoutError {
                continue
            } catch let error as PaywallError {
                throw error
            } catch {
                throw PaywallError.interceptorBlocked(reason: error.localizedDescription)
            }
        }

        isLoading = true
        defer { isLoading = false }

        let products: [Product]
        if let cached = await cache.read(type) {
            products = cached.products
            Task.detached { [weak self] in
                guard let self else { return }
                do {
                    let fresh = try await self.provider.products(for: type, mode: config.productMode)
                    await self.cache.write(type, products: fresh)
                    await self.applyFreshProducts(type: type, products: fresh)
                } catch {
                    // revalidation failed silently
                }
            }
        } else {
            do {
                let fetched = try await provider.products(for: type, mode: config.productMode)
                await cache.write(type, products: fetched)
                products = fetched
            } catch let error as PaywallError {
                lastError = error
                throw error
            } catch {
                let wrapped = PaywallError(error)
                lastError = wrapped
                throw wrapped
            }
        }

        applySelection(products: products, config: config)
        presentedType = type
        currentConfiguration = config
        lastError = nil

        emit(.didAppear(type: type))
    }

    public func dismiss(
        reason: DismissReason = .user,
        didPurchase: Bool = false,
        purchasedProductID: String? = nil
    ) async {
        guard let type = presentedType else { return }
        let context = DismissContext(
            paywallType: type,
            reason: reason,
            didPurchase: didPurchase,
            purchasedProductID: purchasedProductID
        )

        emit(.willDismiss(context: context))

        for interceptor in interceptors {
            try? await withTimeout(seconds: purchaseOptions.interceptorTimeout) {
                await interceptor.willDismiss(context: context)
            }
        }

        presentedType = nil
        currentConfiguration = nil
        selection.clear()

        emit(.didDismiss(context: context))

        if !queue.isEmpty {
            let next = queue.removeFirst()
            Task { [weak self] in
                try? await self?.present(next.type)
            }
        }
    }

    // MARK: - Purchase

    public func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }

        emit(.didTapCTA(productID: product.id))
        emit(.purchaseStarted(productID: product.id))

        do {
            let result = try await coordinator.purchase(product)
            switch result.outcome {
            case .success(let transaction):
                emit(.purchaseSucceeded(transaction: transaction))
                await refreshEntitlementsOrFallback(to: transaction)
                await dismiss(
                    reason: .afterPurchase,
                    didPurchase: true,
                    purchasedProductID: transaction.productID
                )
            case .cancelled:
                emit(.purchaseCancelled(productID: product.id))
            case .pending:
                emit(.purchasePending(productID: product.id))
            }
        } catch let error as PaywallError {
            lastError = error
            if case .userCancelled = error {
                emit(.purchaseCancelled(productID: product.id))
            } else {
                emit(.purchaseFailed(productID: product.id, error: error))
            }
            throw error
        } catch {
            let wrapped = PaywallError(error)
            lastError = wrapped
            emit(.purchaseFailed(productID: product.id, error: wrapped))
            throw wrapped
        }
    }

    public func purchaseSelected() async throws {
        guard let product = selection.selected else {
            throw PaywallError.productNotFound(id: "<no selection>")
        }
        try await purchase(product)
    }

    // MARK: - Restore

    public func restore() async throws {
        isLoading = true
        defer { isLoading = false }
        emit(.restoreStarted)
        do {
            let result = try await coordinator.restore()
            entitlements.set(result)
            emit(.restoreSucceeded(entitlements: result))
        } catch let error as PaywallError {
            lastError = error
            emit(.restoreFailed(error: error))
            throw error
        } catch {
            let wrapped = PaywallError(error)
            lastError = wrapped
            emit(.restoreFailed(error: wrapped))
            throw wrapped
        }
    }

    // MARK: - Reward Ads

    public func isRewardAdReady() async -> Bool {
        guard let config = currentConfiguration,
              case .enabled = config.rewardAd,
              let provider = rewardAdProvider else { return false }
        return await provider.isReady()
    }

    public func showRewardAd() async {
        guard let config = currentConfiguration,
              case .enabled(let action) = config.rewardAd,
              let rewardAdProvider
        else {
            emit(.rewardAdFailed(error: .rewardAdNotReady))
            return
        }

        emit(.rewardAdRequested)
        do {
            let outcome = try await rewardAdProvider.show()
            guard outcome.earned else {
                emit(.rewardAdFailed(error: .rewardAdNotReady))
                return
            }
            emit(.rewardAdEarned(outcome: outcome))
            await applyRewardAction(action, outcome: outcome)
        } catch {
            emit(.rewardAdFailed(error: PaywallError(error)))
        }
    }

    // MARK: - Queue

    public func clearQueue() {
        queue.removeAll()
    }

    public var pendingCount: Int { queue.count }

    // MARK: - Private

    private func applySelection(products: [Product], config: PaywallConfiguration) {
        switch config.productMode {
        case .single(let id):
            selection.update(available: products, strategy: .byID(id), forcedID: id)
        case .multi(let strategy):
            selection.update(available: products, strategy: strategy)
        }
    }

    private func applyFreshProducts(type: PaywallType, products: [Product]) async {
        guard presentedType == type, let config = currentConfiguration else { return }
        applySelection(products: products, config: config)
    }

    private func applyRewardAction(_ action: RewardOutcomeAction, outcome: RewardOutcome) async {
        switch action {
        case .grantEphemeral(let id, let duration):
            entitlements.grantEphemeral(id, until: Date().addingTimeInterval(duration))
        case .switchSelection(let id):
            selection.selectByID(id)
        case .custom(let handler):
            let result = await handler(outcome)
            switch result {
            case .grantEphemeral(let id, let duration):
                entitlements.grantEphemeral(id, until: Date().addingTimeInterval(duration))
            case .switchSelection(let id):
                selection.selectByID(id)
            case .dismissPaywall:
                await dismiss(reason: .programmatic)
            case .noop:
                break
            }
        }
    }

    private func refreshEntitlementsOrFallback(to transaction: VerifiedTransaction) async {
        do {
            let fresh = try await provider.refreshEntitlements()
            entitlements.set(fresh)
        } catch {
            entitlements.upsert(Entitlement(
                id: Entitlement.ID(transaction.productID),
                productID: transaction.productID,
                expiresAt: transaction.expirationDate,
                source: .purchase
            ))
        }
    }

    private func startTransactionListener() {
        transactionListenerTask = Task { [weak self] in
            guard let self else { return }
            for await transaction in self.provider.transactionUpdates {
                await self.handleBackgroundTransaction(transaction)
            }
        }
    }

    private func handleBackgroundTransaction(_ transaction: VerifiedTransaction) async {
        await refreshEntitlementsOrFallback(to: transaction)
        emit(.purchaseSucceeded(transaction: transaction))
    }

    private func emit(_ event: PaywallEvent) {
        eventContinuation.yield(event)
        for observer in analytics {
            Task.detached(priority: .utility) {
                await observer.observe(event)
            }
        }
    }
}

private struct QueuedPaywall: Sendable {
    let type: PaywallType
    let config: PaywallConfiguration
}
