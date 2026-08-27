import Foundation

public enum RideVehicleIdentity: Equatable, Hashable, Sendable {
    case temporary(UUID)
    case vin(String)

    public var confirmedVIN: String? {
        guard case .vin(let value) = self else { return nil }
        return value
    }

    public var temporaryID: UUID? {
        guard case .temporary(let value) = self else { return nil }
        return value
    }
}

public struct BikeSessionContext: Equatable, Sendable {
    public let applicationSessionID: UUID
    public let connectionID: UUID
    public let vehicleIdentity: RideVehicleIdentity

    public init(
        applicationSessionID: UUID,
        connectionID: UUID = UUID(),
        vehicleIdentity: RideVehicleIdentity
    ) {
        self.applicationSessionID = applicationSessionID
        self.connectionID = connectionID
        self.vehicleIdentity = vehicleIdentity
    }

    public func promoting(to vin: String) -> Self {
        .init(
            applicationSessionID: applicationSessionID,
            connectionID: connectionID,
            vehicleIdentity: .vin(vin)
        )
    }
}
