import Foundation
import Security

public protocol EntitlementPersistence: Sendable {
    func load() throws -> Set<Entitlement>
    func save(_ entitlements: Set<Entitlement>) throws
    func clear() throws
}

public struct InMemoryEntitlementPersistence: EntitlementPersistence {
    private final class Box: @unchecked Sendable {
        var value: Set<Entitlement> = []
    }
    private let box = Box()

    public init(initial: Set<Entitlement> = []) {
        box.value = initial
    }

    public func load() throws -> Set<Entitlement> { box.value }
    public func save(_ entitlements: Set<Entitlement>) throws { box.value = entitlements }
    public func clear() throws { box.value = [] }
}

public struct KeychainEntitlementPersistence: EntitlementPersistence {
    public let service: String
    public let account: String

    public init(
        service: String = "com.paywallkit.entitlements",
        account: String = "active-entitlements"
    ) {
        self.service = service
        self.account = account
    }

    public func load() throws -> Set<Entitlement> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.loadFailed(status: status)
        }
        return (try? JSONDecoder().decode(Set<Entitlement>.self, from: data)) ?? []
    }

    public func save(_ entitlements: Set<Entitlement>) throws {
        let data = try JSONEncoder().encode(entitlements)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    public func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.clearFailed(status: status)
        }
    }
}

public enum KeychainError: Error, Sendable {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case clearFailed(status: OSStatus)
}
