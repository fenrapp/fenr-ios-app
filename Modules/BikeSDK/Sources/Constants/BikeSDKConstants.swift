import CoreBluetooth
import StarkProtocol

enum BikeSDKConstants {
    static var cccdUUID: CBUUID { CBUUID(string: "2902") }
    static var bikeServiceUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.bikeService) }
    static let securityRequiredProperties: CBCharacteristicProperties = [.read, .write, .notify]
    static var scanOptions: [String: Any] { [
        CBCentralManagerScanOptionAllowDuplicatesKey: false
    ] }

    static var serviceUUIDs: [CBUUID] { BikeBLEDiagnosticsProfile.serviceUUIDs }

    static var characteristicUUIDs: [CBUUID] { BikeBLEDiagnosticsProfile.characteristicUUIDs }

    static var requiredServiceUUIDs: [CBUUID] { BikeBLEDiagnosticsProfile.requiredServiceUUIDs }

    static var securityCharacteristicUUID: CBUUID {
        BikeBLEDiagnosticsProfile.securityUUID
    }

    static var batterySOCCharacteristicUUID: CBUUID { BikeBLEDiagnosticsProfile.batterySOCUUID }

    static var bikeStatusCharacteristicUUID: CBUUID { BikeBLEDiagnosticsProfile.bikeStatusUUID }

    static var vcuVersionsUUID: CBUUID { BikeBLEDiagnosticsProfile.vcuVersionsUUID }

    static var vcuBikeConfigurationUUID: CBUUID { BikeBLEDiagnosticsProfile.vcuBikeConfigurationUUID }

    static var telemetryCharacteristicUUIDs: [CBUUID] {
        BikeBLEDiagnosticsProfile.telemetryCharacteristicUUIDs
    }

    // Each of these decoded datasets supplies a dashboard metric on its own.
    static var dashboardTelemetryUUIDs: [CBUUID] {
        [CBUUID(nsuuid: StarkUUIDs.liveSpeed), batterySOCCharacteristicUUID, CBUUID(nsuuid: StarkUUIDs.liveTotals)]
    }

    static var requiredTelemetryNotifyUUIDs: [CBUUID] {
        BikeBLEDiagnosticsProfile.requiredTelemetryNotifyUUIDs
    }

    static var telemetrySnapshotUUIDs: [CBUUID] {
        BikeBLEDiagnosticsProfile.telemetrySnapshotUUIDs
    }

    static var batteryHealthMonitoringUUIDs: [CBUUID] {
        BikeBLEDiagnosticsProfile.batteryHealthMonitoringUUIDs
    }

    static var imuMonitoringUUID: CBUUID {
        BikeBLEDiagnosticsProfile.imuMonitoringUUID
    }

    static var experimentalCaptureUUIDs: [CBUUID] {
        BikeBLEDiagnosticsProfile.experimentalCaptureUUIDs
    }

    static func batteryDataset(for uuid: CBUUID) -> BikeSDKBatteryDataset? {
        BikeBLEDiagnosticsProfile.batteryDataset(for: uuid)
    }

    static func characteristicUUIDs(for serviceUUID: CBUUID) -> [CBUUID] {
        BikeBLEDiagnosticsProfile.characteristicUUIDs(for: serviceUUID)
    }

    static func requiredCharacteristicUUIDs(for serviceUUID: CBUUID) -> [CBUUID] {
        BikeBLEDiagnosticsProfile.requiredCharacteristicUUIDs(for: serviceUUID)
    }
}
