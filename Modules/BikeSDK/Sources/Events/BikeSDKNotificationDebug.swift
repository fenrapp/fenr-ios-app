import Foundation

public struct BikeSDKNotificationDebug: Equatable, Sendable {
    public let characteristic: UUID
    public let byteCount: Int
    public let hex: String
    public let decodedDetail: String?
    public let date: Date

    public init(
        characteristic: UUID,
        byteCount: Int,
        hex: String,
        decodedDetail: String? = nil,
        date: Date
    ) {
        self.characteristic = characteristic
        self.byteCount = byteCount
        self.hex = hex
        self.decodedDetail = decodedDetail
        self.date = date
    }
}
