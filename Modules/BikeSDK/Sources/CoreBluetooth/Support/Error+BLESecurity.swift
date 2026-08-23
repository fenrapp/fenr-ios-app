import CoreBluetooth
import Foundation

extension Error {
    var requiresPairingOrEncryption: Bool {
        let nsError = self as NSError
        guard nsError.domain == CBATTError.errorDomain else { return false }
        return nsError.code == CBATTError.Code.insufficientAuthentication.rawValue
            || nsError.code == CBATTError.Code.insufficientEncryption.rawValue
    }
}
