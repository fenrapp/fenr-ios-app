import Foundation
import RuntimeConfiguration

enum CoreBluetoothRestorationPolicy {
    static func restorationIdentifier(for bundle: Bundle) -> String? {
        guard supportsBluetoothCentralBackgroundMode(bundle: bundle) else {
            return nil
        }
        return FENRRuntimeConstants.BikeSDK.centralRestorationIdentifier
    }

    private static func supportsBluetoothCentralBackgroundMode(bundle: Bundle) -> Bool {
        let modes = bundle.object(
            forInfoDictionaryKey: FENRRuntimeConstants.BikeSDK.backgroundModesInfoPlistKey
        ) as? [String]
        return modes?.contains(FENRRuntimeConstants.BikeSDK.bluetoothCentralBackgroundMode) == true
    }
}
