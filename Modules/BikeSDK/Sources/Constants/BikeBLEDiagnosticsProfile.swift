import CoreBluetooth
import StarkProtocol

enum BikeBLECurrentObservedFirmwareProfile {
    static var services: [BikeBLEServiceProfile] {
        [statusService, liveService, batteryService, chargerService, vcuService, inverterService]
    }

    static var serviceUUIDs: [CBUUID] {
        services.map(\.serviceUUID)
    }

    static var characteristicUUIDs: [CBUUID] {
        services.flatMap(\.characteristicUUIDs)
    }

    static var telemetryCharacteristicUUIDs: [CBUUID] {
        [
            statusUUID,
            speedUUID,
            mapUUID,
            liveTotalsUUID,
            liveEstimationsUUID,
            batterySOCUUID,
            batteryParamsUUID,
            batterySignalsUUID,
            vcuTelemetryTLVUUID
        ]
    }

    static var requiredTelemetryNotifyUUIDs: [CBUUID] {
        [statusUUID, speedUUID, mapUUID, liveTotalsUUID, batterySOCUUID, vcuTelemetryTLVUUID]
    }

    static var telemetrySnapshotUUIDs: [CBUUID] {
        [batterySOCUUID, liveEstimationsUUID, batteryParamsUUID, batterySignalsUUID]
    }

    // These UUIDs still need protocol characterization. Charge power control uses only 4005 after prepare guards.
    static var experimentalCaptureUUIDs: [CBUUID] {
        [
            bikeTelemetryTLVUUID,
            liveTelemetryTLVUUID,
            chargerTelemetryTLVUUID,
            batteryTelemetryTLVUUID,
            inverterInfoUUID,
            inverterSignalsUUID,
            inverterPCBUUID,
            inverterTelemetryTLVUUID
        ]
    }

    static var batteryHealthMonitoringUUIDs: [CBUUID] {
        [
            batteryStatusUUID,
            batteryTemperaturesUUID,
            batteryDCBusUUID,
            batteryCellVoltagesUUID,
            batteryBalancingUUID,
            batterySignalsUUID,
            chargerDataUUID,
            inverterTemperaturesUUID
        ]
    }

    static var requiredServiceUUIDs: [CBUUID] {
        [statusService.serviceUUID, liveService.serviceUUID, batteryService.serviceUUID]
    }

    static func characteristicUUIDs(for serviceUUID: CBUUID) -> [CBUUID] {
        services.first(where: { $0.serviceUUID == serviceUUID })?.characteristicUUIDs ?? []
    }

    static func requiredCharacteristicUUIDs(for serviceUUID: CBUUID) -> [CBUUID] {
        switch serviceUUID {
        case statusService.serviceUUID:
            [securityUUID, statusUUID]
        case liveService.serviceUUID:
            [speedUUID, mapUUID]
        case batteryService.serviceUUID:
            [batterySOCUUID]
        default:
            []
        }
    }

    static var securityUUID: CBUUID {
        CBUUID(nsuuid: StarkUUIDs.bikeSecurity)
    }

    static var batterySOCUUID: CBUUID {
        CBUUID(nsuuid: StarkUUIDs.batterySOC)
    }

    static var bikeStatusUUID: CBUUID {
        CBUUID(nsuuid: StarkUUIDs.bikeStatus)
    }

    static func batteryDataset(for uuid: CBUUID) -> BikeSDKBatteryDataset? {
        switch uuid {
        case batteryStatusUUID: .bmsStatus
        case batteryTemperaturesUUID: .temperatures
        case batteryDCBusUUID: .dcBus
        case batteryCellVoltagesUUID: .cellVoltages
        case batteryBalancingUUID: .balancing
        case batterySignalsUUID: .signals
        case chargerDataUUID: .charger
        default: nil
        }
    }

    private static var statusUUID: CBUUID { bikeStatusUUID }

    private static var speedUUID: CBUUID {
        CBUUID(nsuuid: StarkUUIDs.liveSpeed)
    }

    private static var mapUUID: CBUUID {
        CBUUID(nsuuid: StarkUUIDs.liveMap)
    }

    private static var bikeTelemetryTLVUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.bikeTelemetryTLV) }
    private static var liveThrottleUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.liveThrottle) }
    private static var liveIMUUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.liveIMU) }
    private static var liveTotalsUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.liveTotals) }
    private static var liveEstimationsUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.liveEstimation) }
    private static var liveTelemetryTLVUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.liveTelemetryTLV) }

    private static var batteryStatusUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.batteryStatus) }
    private static var batteryParamsUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.batteryParams) }
    private static var batteryTemperaturesUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.batteryTemperatures) }
    private static var batteryDCBusUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.batteryDCBus) }
    private static var batteryCellVoltagesUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.batteryCellVoltages) }
    private static var batteryBalancingUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.batteryBalancing) }
    private static var batterySignalsUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.batterySignals) }
    private static var batteryTelemetryTLVUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.batteryTelemetryTLV) }
    private static var chargerDataUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.chargerData) }
    private static var chargerTelemetryTLVUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.chargerTelemetryTLV) }
    static var vcuVersionsUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.vcuVersions) }
    static var vcuBikeConfigurationUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.vcuBikeConfiguration) }
    private static var vcuTelemetryTLVUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.vcuTelemetryTLV) }
    private static var inverterInfoUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.inverterInfo) }
    private static var inverterSignalsUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.inverterSignals) }
    private static var inverterTemperaturesUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.inverterTemperatures) }
    private static var inverterPCBUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.inverterPCB) }
    private static var inverterTelemetryTLVUUID: CBUUID { CBUUID(nsuuid: StarkUUIDs.inverterTelemetryTLV) }

    private static var statusService: BikeBLEServiceProfile {
        BikeBLEServiceProfile(
            serviceUUID: CBUUID(nsuuid: StarkUUIDs.bikeService),
            characteristicUUIDs: [securityUUID, statusUUID, bikeTelemetryTLVUUID]
        )
    }

    private static var liveService: BikeBLEServiceProfile {
        BikeBLEServiceProfile(
            serviceUUID: CBUUID(nsuuid: StarkUUIDs.liveService),
            characteristicUUIDs: [
                speedUUID,
                liveThrottleUUID,
                liveIMUUUID,
                mapUUID,
                liveTotalsUUID,
                liveEstimationsUUID,
                liveTelemetryTLVUUID
            ]
        )
    }

    private static var batteryService: BikeBLEServiceProfile {
        BikeBLEServiceProfile(
            serviceUUID: CBUUID(nsuuid: StarkUUIDs.batteryService),
            characteristicUUIDs: [
                batteryStatusUUID,
                batteryParamsUUID,
                batterySOCUUID,
                batteryTemperaturesUUID,
                batteryDCBusUUID,
                batteryCellVoltagesUUID,
                batteryBalancingUUID,
                batterySignalsUUID,
                batteryTelemetryTLVUUID
            ]
        )
    }

    private static var chargerService: BikeBLEServiceProfile {
        BikeBLEServiceProfile(
            serviceUUID: CBUUID(nsuuid: StarkUUIDs.chargerService),
            characteristicUUIDs: [chargerDataUUID, chargerTelemetryTLVUUID]
        )
    }

    private static var vcuService: BikeBLEServiceProfile {
        BikeBLEServiceProfile(
            serviceUUID: CBUUID(nsuuid: StarkUUIDs.vcuService),
            characteristicUUIDs: [vcuVersionsUUID, vcuBikeConfigurationUUID, vcuTelemetryTLVUUID]
        )
    }

    private static var inverterService: BikeBLEServiceProfile {
        BikeBLEServiceProfile(
            serviceUUID: CBUUID(nsuuid: StarkUUIDs.inverterService),
            characteristicUUIDs: [
                inverterInfoUUID,
                inverterSignalsUUID,
                inverterTemperaturesUUID,
                inverterPCBUUID,
                inverterTelemetryTLVUUID
            ]
        )
    }
}
