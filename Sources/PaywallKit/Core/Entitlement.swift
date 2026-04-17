import Foundation

public struct Entitlement: Hashable, Sendable {
    public struct ID: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public init(stringLiteral value: String) { self.rawValue = value }
    }

    public enum Source: String, Sendable, Codable {
        case purchase
        case restore
        case rewardAd
        case promotion
        case manual
    }

    public let id: ID
    public let productID: String?
    public let expiresAt: Date?
    public let isEphemeral: Bool
    public let source: Source

    public init(
        id: ID,
        productID: String? = nil,
        expiresAt: Date? = nil,
        isEphemeral: Bool = false,
        source: Source = .purchase
    ) {
        self.id = id
        self.productID = productID
        self.expiresAt = expiresAt
        self.isEphemeral = isEphemeral
        self.source = source
    }

    public var isActive: Bool {
        guard let expiresAt else { return true }
        return expiresAt > Date()
    }
}

extension Entitlement: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, productID, expiresAt, isEphemeral, source
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = ID(try c.decode(String.self, forKey: .id))
        self.productID = try c.decodeIfPresent(String.self, forKey: .productID)
        self.expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
        self.isEphemeral = try c.decode(Bool.self, forKey: .isEphemeral)
        self.source = try c.decode(Source.self, forKey: .source)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.rawValue, forKey: .id)
        try c.encodeIfPresent(productID, forKey: .productID)
        try c.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try c.encode(isEphemeral, forKey: .isEphemeral)
        try c.encode(source, forKey: .source)
    }
}
