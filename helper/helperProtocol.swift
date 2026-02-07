import Foundation

@objc protocol HelperProtocol {
    func readSMCPower(reply: @escaping (Double, Double, Double) -> Void)
}
