import Foundation

public struct StarkNotificationDecoderRegistry: Sendable {
    private let decoders: [UUID: StarkNotificationDecoder]

    public init(decoders: [UUID: StarkNotificationDecoder]) {
        self.decoders = decoders
    }

    public func decode(characteristic: UUID, data: Data) throws -> BikeSDKTelemetryPayload? {
        try decoders[characteristic]?.decode(data)
    }
}
