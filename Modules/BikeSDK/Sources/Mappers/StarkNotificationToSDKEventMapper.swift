import Foundation

public struct StarkNotificationToSDKEventMapper: Sendable {
    private let decoderRegistry: StarkNotificationDecoderRegistry

    public init(decoderRegistry: StarkNotificationDecoderRegistry) {
        self.decoderRegistry = decoderRegistry
    }

    public func telemetryPayload(characteristic: UUID, data: Data) throws -> BikeSDKTelemetryPayload? {
        try decoderRegistry.decode(characteristic: characteristic, data: data)
    }

    public func debug(characteristic: UUID, data: Data, date: Date) -> BikeSDKNotificationDebug {
        BikeSDKNotificationDebug(
            characteristic: characteristic,
            byteCount: data.count,
            hex: data.bikeSDKHexString,
            date: date
        )
    }
}
