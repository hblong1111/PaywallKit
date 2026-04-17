import Foundation

@MainActor
@Observable
public final class EntitlementStore {
    public private(set) var active: Set<Entitlement> = []
    private let persistence: any EntitlementPersistence

    public init(persistence: any EntitlementPersistence = KeychainEntitlementPersistence()) {
        self.persistence = persistence
        self.active = (try? persistence.load()) ?? []
        removeExpired()
    }

    public var isSubscribed: Bool {
        active.contains { !$0.isEphemeral && $0.isActive }
    }

    public var hasAnyActive: Bool {
        active.contains { $0.isActive }
    }

    public func has(_ id: Entitlement.ID) -> Bool {
        active.contains { $0.id == id && $0.isActive }
    }

    public func entitlement(for id: Entitlement.ID) -> Entitlement? {
        active.first { $0.id == id && $0.isActive }
    }

    /// Thay toàn bộ entitlement bền (non-ephemeral). Entitlement ephemeral hiện có được giữ lại.
    public func set(_ entitlements: Set<Entitlement>) {
        let nonEphemeral = entitlements.filter { !$0.isEphemeral }
        let ephemeralActive = active.filter { $0.isEphemeral && $0.isActive }
        active = nonEphemeral.union(ephemeralActive)
        persist()
    }

    /// Thêm/cập nhật 1 entitlement bền.
    public func upsert(_ entitlement: Entitlement) {
        active = active.filter { $0.id != entitlement.id }.union([entitlement])
        if !entitlement.isEphemeral { persist() }
    }

    /// Cấp entitlement tạm thời (ví dụ sau reward ads). Tự auto-revoke khi tới hạn.
    /// Không persist — mất khi kill app (by design).
    public func grantEphemeral(_ id: Entitlement.ID, until: Date) {
        let entitlement = Entitlement(
            id: id,
            expiresAt: until,
            isEphemeral: true,
            source: .rewardAd
        )
        active = active.filter { $0.id != id || !$0.isEphemeral }.union([entitlement])

        let delay = until.timeIntervalSinceNow
        guard delay > 0 else { return }
        Task.detached { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            await self?.removeExpired()
        }
    }

    public func revoke(_ id: Entitlement.ID) {
        let removed = active.contains { $0.id == id && !$0.isEphemeral }
        active = active.filter { $0.id != id }
        if removed { persist() }
    }

    public func clear() {
        active = []
        try? persistence.clear()
    }

    private func removeExpired() {
        let before = active.count
        active = active.filter { $0.isActive }
        if active.count != before {
            let hadPersisted = active.contains { !$0.isEphemeral }
            if !hadPersisted {
                try? persistence.save(active.filter { !$0.isEphemeral })
            } else {
                persist()
            }
        }
    }

    private func persist() {
        try? persistence.save(active.filter { !$0.isEphemeral })
    }
}
