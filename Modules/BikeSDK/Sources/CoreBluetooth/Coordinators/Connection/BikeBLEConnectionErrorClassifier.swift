import CoreBluetooth
import Foundation

struct BikeBLEConnectionErrorClassifier: Sendable {
    func requiresPairingReset(_ error: Error?) -> Bool {
        guard let error else { return false }
        return containsPairingResetError(error as NSError)
    }

    func diagnosticDetail(_ error: Error?) -> String {
        guard let error else { return "domain=none code=none description=none" }
        let nsError = error as NSError
        return "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
    }

    private func containsPairingResetError(_ error: NSError) -> Bool {
        if isPairingResetError(error) {
            return true
        }
        guard let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError else {
            return false
        }
        return containsPairingResetError(underlyingError)
    }

    private func isPairingResetError(_ error: NSError) -> Bool {
        let pairingResetCode = CBError.peerRemovedPairingInformation.rawValue
        if error.domain == CBErrorDomain && error.code == pairingResetCode {
            return true
        }
        return error.localizedDescription.localizedCaseInsensitiveCompare(
            "Peer removed pairing information"
        ) == .orderedSame
    }
}
