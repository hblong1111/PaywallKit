import Testing
@testable import PaywallKit

@Suite("PaywallType")
struct PaywallTypeTests {
    @Test
    func stringLiteralInit() {
        let t: PaywallType = "onboarding"
        #expect(t.rawValue == "onboarding")
    }

    @Test
    func hashable() {
        let a: PaywallType = "a"
        let b: PaywallType = "a"
        let c: PaywallType = "c"
        #expect(a == b)
        #expect(a != c)
    }
}

@Suite("PaywallError")
struct PaywallErrorTests {
    @Test
    func wrapsUnknownError() {
        struct Boom: Error {}
        let err = PaywallError(Boom())
        if case .unknown = err {
            return
        }
        Issue.record("Expected .unknown, got \(err)")
    }

    @Test
    func preservesPaywallError() {
        let original = PaywallError.productNotFound(id: "x")
        let wrapped = PaywallError(original)
        #expect(wrapped == .productNotFound(id: "x"))
    }
}

@Suite("PaywallConfiguration")
struct PaywallConfigurationTests {
    @Test
    func defaultsApply() {
        let config = PaywallConfiguration(productMode: .single(productID: "sku"))
        #expect(config.closeButton == .alwaysVisible)
        #expect(config.allowsQueue == true)
        if case .disabled = config.rewardAd { return }
        Issue.record("Expected rewardAd .disabled")
    }
}
