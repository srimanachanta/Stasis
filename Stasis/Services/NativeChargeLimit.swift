import Foundation
import ObjectiveC

enum NativeChargeLimitError: LocalizedError {
    case unavailable
    case unsupportedLimit(Int)
    case verificationFailed(expected: Int?, actual: Int?)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            String(localized: "The macOS charge limit is unavailable on this Mac.")
        case .unsupportedLimit(let limit):
            String(localized: "macOS does not support a charge limit of \(limit)%.")
        case .verificationFailed(let expected, let actual):
            String(
                localized:
                    "macOS did not apply the charge limit (expected \(expected.map { "\($0)%" } ?? "off"), got \(actual.map { "\($0)%" } ?? "off")).")
        }
    }
}

/// Mirrors the subset of the private `PowerUISmartChargeClient` class used by Stasis. The class is
/// made to conform at runtime so calls go through regular Objective-C dispatch with ARC-correct
/// initialization, without a bridging header.
@objc nonisolated private protocol SmartChargeClient: NSObjectProtocol {
    @objc(initWithClientName:) init(clientName: String)
    @objc(isMCLSupported) func isMCLSupported() -> Bool
    @objc(availableChargeLimitsWithError:) func availableChargeLimits() throws -> [NSNumber]
    @objc(getMCLLimitWithError:) func chargeLimit(error: NSErrorPointer) -> UInt8
    @objc(isMCLCurrentlyEnabled:) func isChargeLimitEnabled(error: NSErrorPointer) -> UInt64
    @objc(setMCLLimit:error:) func setChargeLimit(_ limit: UInt8) throws
    @objc(disableMCL:) func disableChargeLimit() throws
}

/// Controls the macOS Charge Limit (System Settings > Battery) through PowerUI. On macOS 27 firmware
/// the SMC charge-inhibit keys are entitlement-gated, so this is the only instant, unprivileged way
/// to limit charging.
actor NativeChargeLimit {
    private static let frameworkPath = "/System/Library/PrivateFrameworks/PowerUI.framework"
    private static let clientClassName = "PowerUISmartChargeClient"
    private static let requiredSelectors = [
        "initWithClientName:", "isMCLSupported", "availableChargeLimitsWithError:",
        "getMCLLimitWithError:", "isMCLCurrentlyEnabled:", "setMCLLimit:error:", "disableMCL:",
    ]

    nonisolated let availableLimits: [Int]
    private let client: any SmartChargeClient

    init?() {
        guard Bundle(path: Self.frameworkPath)?.load() == true,
            let clientClass = NSClassFromString(Self.clientClassName),
            Self.requiredSelectors.allSatisfy({
                class_respondsToSelector(clientClass, NSSelectorFromString($0))
            })
        else { return nil }

        class_addProtocol(clientClass, SmartChargeClient.self)
        guard let clientType = clientClass as? SmartChargeClient.Type else { return nil }

        let client = clientType.init(clientName: "com.srimanachanta.stasis")
        guard client.isMCLSupported(),
            let limits = try? client.availableChargeLimits().map(\.intValue).sorted(),
            !limits.isEmpty
        else { return nil }

        self.client = client
        self.availableLimits = limits
    }

    func apply(limit: Int) throws {
        guard availableLimits.contains(limit), let value = UInt8(exactly: limit) else {
            throw NativeChargeLimitError.unsupportedLimit(limit)
        }
        try client.setChargeLimit(value)

        let current = try currentLimit()
        guard current == limit else {
            throw NativeChargeLimitError.verificationFailed(expected: limit, actual: current)
        }
    }

    func disable() throws {
        try client.disableChargeLimit()

        let current = try currentLimit()
        guard current == nil else {
            throw NativeChargeLimitError.verificationFailed(expected: nil, actual: current)
        }
    }

    /// Returns `nil` when the limit is disabled.
    private func currentLimit() throws -> Int? {
        var error: NSError?
        let enabled = client.isChargeLimitEnabled(error: &error)
        if let error { throw error }
        guard enabled != 0 else { return nil }

        let limit = client.chargeLimit(error: &error)
        if let error { throw error }
        return Int(limit)
    }
}
