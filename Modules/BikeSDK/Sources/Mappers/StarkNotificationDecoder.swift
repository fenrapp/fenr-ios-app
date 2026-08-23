import Foundation
import StarkProtocol

public struct StarkNotificationDecoder: Sendable {
    private let decodePayload: @Sendable (Data) throws -> BikeSDKTelemetryPayload?

    private init(decodePayload: @escaping @Sendable (Data) throws -> BikeSDKTelemetryPayload?) {
        self.decodePayload = decodePayload
    }

    public static func adapting<Decoder: StarkPayloadDecoding>(
        decoder: Decoder,
        transform: @escaping @Sendable (Decoder.Payload) -> BikeSDKTelemetryPayload
    ) -> StarkNotificationDecoder {
        StarkNotificationDecoder(
            decodePayload: { data in
                transform(try decoder.decode(data))
            }
        )
    }

    public static func adapting<Decoder: StarkPayloadDecoding>(
        decoder: Decoder,
        when shouldDecode: @escaping @Sendable (Data) -> Bool,
        transform: @escaping @Sendable (Decoder.Payload) -> BikeSDKTelemetryPayload
    ) -> StarkNotificationDecoder {
        StarkNotificationDecoder(
            decodePayload: { data in
                guard shouldDecode(data) else { return nil }
                return transform(try decoder.decode(data))
            }
        )
    }

    public func decode(_ data: Data) throws -> BikeSDKTelemetryPayload? {
        try decodePayload(data)
    }
}
