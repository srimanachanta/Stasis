import Foundation

@objc protocol HelperProtocol {
    func readSMCPower(reply: @escaping @Sendable (Double, Double, Double) -> Void)
}
