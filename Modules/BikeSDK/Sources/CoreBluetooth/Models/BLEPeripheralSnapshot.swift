import Foundation

public struct BLEPeripheralSnapshot: Equatable, Sendable {
    public let name: String?
    public let identifier: UUID
    public let rssi: Int?

    public init(name: String?, identifier: UUID, rssi: Int? = nil) {
        self.name = name
        self.identifier = identifier
        self.rssi = rssi
    }
}
