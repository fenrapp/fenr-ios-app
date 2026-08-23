import Foundation

public enum StarkUUIDCatalog {
    public static let services = [
        StarkUUIDs.bikeService,
        StarkUUIDs.liveService,
        StarkUUIDs.dockService,
        StarkUUIDs.vcuService,
        StarkUUIDs.chargerService,
        StarkUUIDs.batteryService,
        StarkUUIDs.inverterService,
        StarkUUIDs.lightsService
    ]

    public static let proprietaryCharacteristics = bikeCharacteristics
        + liveCharacteristics
        + dockCharacteristics
        + vcuCharacteristics
        + chargerCharacteristics
        + batteryCharacteristics
        + inverterCharacteristics
        + lightsCharacteristics

    public static let standardCharacteristics = [StarkUUIDs.bikeBatteryLevel]

    private static let bikeCharacteristics = [
        StarkUUIDs.bikeSecurity,
        StarkUUIDs.bikeStatus,
        StarkUUIDs.vin,
        StarkUUIDs.bikeVersions,
        StarkUUIDs.phoneSOC,
        StarkUUIDs.bikeTelemetryTLV,
        StarkUUIDs.bikeTelemetryTLVConfiguration
    ]

    private static let liveCharacteristics = [
        StarkUUIDs.liveSpeed,
        StarkUUIDs.liveThrottle,
        StarkUUIDs.liveIMU,
        StarkUUIDs.liveMap,
        StarkUUIDs.liveTotals,
        StarkUUIDs.liveEstimation,
        StarkUUIDs.liveRacing,
        StarkUUIDs.liveConfiguration,
        StarkUUIDs.liveTelemetryTLV,
        StarkUUIDs.liveTelemetryTLVConfiguration
    ]

    private static let dockCharacteristics = [
        StarkUUIDs.dockVersion,
        StarkUUIDs.dockQiStatus,
        StarkUUIDs.dockTelemetryTLV,
        StarkUUIDs.dockTelemetryTLVConfiguration
    ]

    private static let vcuCharacteristics = [
        StarkUUIDs.vcuVersions,
        StarkUUIDs.vcuInfo,
        StarkUUIDs.vcuBikeConfiguration,
        StarkUUIDs.vcuTelemetryTLV
    ]

    private static let chargerCharacteristics = [
        StarkUUIDs.chargerData,
        StarkUUIDs.chargerTelemetryTLV,
        StarkUUIDs.chargerTelemetryTLVConfiguration
    ]

    private static let batteryCharacteristics = [
        StarkUUIDs.batteryStatus,
        StarkUUIDs.batteryFirmwareVersion,
        StarkUUIDs.batteryParams,
        StarkUUIDs.batterySOC,
        StarkUUIDs.batteryTemperatures,
        StarkUUIDs.batteryDCBus,
        StarkUUIDs.batteryCellVoltages,
        StarkUUIDs.batteryBalancing,
        StarkUUIDs.batterySignals,
        StarkUUIDs.batteryConfiguration,
        StarkUUIDs.batteryTelemetryTLV,
        StarkUUIDs.batteryTelemetryTLVConfiguration
    ]

    private static let inverterCharacteristics = [
        StarkUUIDs.inverterInfo,
        StarkUUIDs.inverterSignals,
        StarkUUIDs.inverterTemperatures,
        StarkUUIDs.inverterPCB,
        StarkUUIDs.inverterTelemetryTLV,
        StarkUUIDs.inverterTelemetryTLVConfiguration
    ]

    private static let lightsCharacteristics = [
        StarkUUIDs.lightsTelemetryTLV,
        StarkUUIDs.lightsTelemetryTLVConfiguration
    ]
}
