import Foundation
import StarkProtocol

enum BikeTelemetryDecoderRegistryFactory {
    static func make() -> StarkNotificationDecoderRegistry {
        StarkNotificationDecoderRegistry(
            decoders: protocolDecoders.merging(
                liveDecoders,
                uniquingKeysWith: { _, replacement in replacement }
            )
        )
    }

    private static let protocolDecoders: [UUID: StarkNotificationDecoder] = [
        StarkUUIDs.batterySOC: .adapting(
            decoder: StarkBatteryDecoder(),
            transform: BikeSDKTelemetryPayload.battery
        ),
        StarkUUIDs.batteryCellVoltages: .adapting(
            decoder: StarkCellVoltagesDecoder(),
            transform: BikeSDKTelemetryPayload.cellVoltages
        ),
        StarkUUIDs.batteryTemperatures: .adapting(
            decoder: StarkBatteryTemperaturesDecoder(),
            transform: BikeSDKTelemetryPayload.batteryTemperatures
        ),
        StarkUUIDs.batteryBalancing: .adapting(
            decoder: StarkBatteryBalancingDecoder(),
            transform: BikeSDKTelemetryPayload.batteryBalancing
        ),
        StarkUUIDs.chargerData: .adapting(
            decoder: StarkChargerDecoder(),
            transform: BikeSDKTelemetryPayload.charger
        ),
        StarkUUIDs.bikeStatus: .adapting(
            decoder: StarkStatusDecoder(),
            transform: BikeSDKTelemetryPayload.status
        ),
        StarkUUIDs.vcuTelemetryTLV: .adapting(
            decoder: StarkVCUBrakeDecoder(),
            when: { $0.starts(with: StarkVCUBrakePayloadLayout.header) },
            transform: BikeSDKTelemetryPayload.vcuBrake
        )
    ]

    private static let liveDecoders: [UUID: StarkNotificationDecoder] = [
        StarkUUIDs.liveMap: .adapting(
            decoder: StarkMapDecoder(),
            transform: { .map($0.modeIndex) }
        ),
        StarkUUIDs.liveSpeed: .adapting(
            decoder: StarkSpeedDecoder(),
            transform: BikeSDKTelemetryPayload.speed
        ),
        StarkUUIDs.liveThrottle: .adapting(
            decoder: StarkThrottleDecoder(),
            transform: BikeSDKTelemetryPayload.throttle
        ),
        StarkUUIDs.liveIMU: .adapting(
            decoder: StarkIMUDecoder(),
            transform: BikeSDKTelemetryPayload.imu
        ),
        StarkUUIDs.liveTotals: .adapting(
            decoder: StarkLiveTotalsDecoder(),
            transform: BikeSDKTelemetryPayload.liveTotals
        ),
        StarkUUIDs.inverterTemperatures: .adapting(
            decoder: StarkInverterTemperaturesDecoder(),
            transform: BikeSDKTelemetryPayload.inverterTemperatures
        ),
        StarkUUIDs.vin: .adapting(
            decoder: StarkVINDecoder(),
            transform: { .vin($0.value) }
        )
    ]
}
