import Foundation

@objc protocol HelperProtocol {
    /// Temperature is NaN when the SMC does not expose it.
    func readBatteryMetrics(
        reply: @escaping @Sendable (Double, Double, Double, Double) -> Void)
    func readAdapterMetrics(
        reply: @escaping @Sendable (Double, Double, Double) -> Void)
    func getCapabilities(
        reply: @escaping @Sendable (Bool, Bool, Bool, Bool) -> Void)
}
