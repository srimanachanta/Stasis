import Foundation

@objc protocol HelperProtocol {
    func readBatteryMetrics(
        reply: @escaping @Sendable (Double, Double, Double, Double, Double, Double, Double) -> Void)
    func getCapabilities(
        reply: @escaping @Sendable (Bool, Bool, Bool, Bool) -> Void)
}
