import CoreBluetooth
import Foundation

extension CBUUID {
    var foundationUUID: UUID {
        UUID(uuidString: uuidString)!
    }
}
