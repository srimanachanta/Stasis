import Foundation

@objc protocol HelperProtocol {
    func readBatteryMetrics(
        reply: @escaping @Sendable (Double, Double, Double) -> Void)
    func readAdapterMetrics(
        reply: @escaping @Sendable (Double, Double, Double) -> Void)
    func getOutputTelemetrySMCKeyAvailability(
        reply: @escaping @Sendable ([String]) -> Void)
    func getCapabilities(
        reply: @escaping @Sendable (Bool, Bool, Bool, Bool) -> Void)
}
