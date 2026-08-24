import Foundation
import RuntimeConfiguration

enum CoreBluetoothRestorationPolicy {
    static func restorationIdentifier(for bundle: Bundle) -> String? {
        return FENRRuntimeConstants.BikeSDK.centralRestorationIdentifier
    }
}
