import CoreBluetooth

/// Firmware capabilities are deliberately scoped to telemetry verified on a physical bike.
/// Add a new case only after capturing and validating that firmware separately.
enum BikeBLEFirmwareProfile: String, Sendable {
    case currentObserved

    static let active = Self.currentObserved
}

enum BikeBLEDiagnosticsProfile {
    static let firmware = BikeBLEFirmwareProfile.active

    static var services: [BikeBLEServiceProfile] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.services
        }
    }

    static var serviceUUIDs: [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.serviceUUIDs
        }
    }

    static var characteristicUUIDs: [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.characteristicUUIDs
        }
    }

    static var telemetryCharacteristicUUIDs: [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.telemetryCharacteristicUUIDs
        }
    }

    static var requiredTelemetryNotifyUUIDs: [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.requiredTelemetryNotifyUUIDs
        }
    }

    static var telemetrySnapshotUUIDs: [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.telemetrySnapshotUUIDs
        }
    }

    static var experimentalCaptureUUIDs: [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.experimentalCaptureUUIDs
        }
    }

    static var batteryHealthMonitoringUUIDs: [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.batteryHealthMonitoringUUIDs
        }
    }

    static var imuMonitoringUUID: CBUUID {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.imuMonitoringUUID
        }
    }

    static var requiredServiceUUIDs: [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.requiredServiceUUIDs
        }
    }

    static var securityUUID: CBUUID {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.securityUUID
        }
    }

    static var batterySOCUUID: CBUUID {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.batterySOCUUID
        }
    }

    static var bikeStatusUUID: CBUUID {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.bikeStatusUUID
        }
    }

    static var vcuVersionsUUID: CBUUID {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.vcuVersionsUUID
        }
    }

    static var vcuBikeConfigurationUUID: CBUUID {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.vcuBikeConfigurationUUID
        }
    }

    static func characteristicUUIDs(for serviceUUID: CBUUID) -> [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.characteristicUUIDs(for: serviceUUID)
        }
    }

    static func requiredCharacteristicUUIDs(for serviceUUID: CBUUID) -> [CBUUID] {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.requiredCharacteristicUUIDs(for: serviceUUID)
        }
    }

    static func batteryDataset(for uuid: CBUUID) -> BikeSDKBatteryDataset? {
        switch firmware {
        case .currentObserved:
            BikeBLECurrentObservedFirmwareProfile.batteryDataset(for: uuid)
        }
    }
}
