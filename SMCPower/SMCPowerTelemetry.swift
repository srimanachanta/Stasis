import SMCKit

public struct SMCPowerTelemetry: Sendable {
    // Candidate keys based on public reverse-engineering references
    // (e.g. Asahi macsmc-power) for adapter/system power telemetry.
    public static let candidateKeys: [String] = [
        "PDTR", // Input power
        "PSTR", // System load
        "PMVR", // Rail power sample used alongside PDTR/PSTR
        "AC-W", // Active charging port index
    ]

    public static func availableCandidateKeys() throws -> [String] {
        try candidateKeys.filter {
            guard let code = fourCharCode(from: $0) else { return false }
            return try SMCKit.shared.isKeyFound(code)
        }
    }

    private static func fourCharCode(from key: String) -> UInt32? {
        guard key.utf8.count == 4 else { return nil }
        return key.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
