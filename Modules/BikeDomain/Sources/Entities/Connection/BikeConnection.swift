import Foundation

public struct BikeConnection: Equatable, Sendable {
    public var state: ConnectionState
    public var peripheralName: String?
    public var peripheralIdentifier: UUID?
    public var rssi: Int?

    public init(
        state: ConnectionState = .idle,
        peripheralName: String? = nil,
        peripheralIdentifier: UUID? = nil,
        rssi: Int? = nil
    ) {
        self.state = state
        self.peripheralName = peripheralName
        self.peripheralIdentifier = peripheralIdentifier
        self.rssi = rssi
    }
}
