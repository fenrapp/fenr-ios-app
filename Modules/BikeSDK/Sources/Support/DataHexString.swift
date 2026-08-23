import Foundation

extension Data {
    var bikeSDKHexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
