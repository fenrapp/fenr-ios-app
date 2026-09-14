import Foundation

public struct BikeChargingPreferences: Codable, Equatable, Sendable {
    public var confirmed: BikeChargePowerConfiguration?
    public var confirmedAt: Date?
    public var selectedCharger: BikeChargerType?
    public var pendingPower: PendingPower?
    public var pendingTarget: PendingTarget?

    public init(
        confirmed: BikeChargePowerConfiguration? = nil, confirmedAt: Date? = nil,
        selectedCharger: BikeChargerType? = nil, pendingPower: PendingPower? = nil,
        pendingTarget: PendingTarget? = nil
    ) {
        self.confirmed = confirmed
        self.confirmedAt = confirmedAt
        self.selectedCharger = selectedCharger
        self.pendingPower = pendingPower
        self.pendingTarget = pendingTarget
    }

    public var hasPendingChanges: Bool { pendingPower != nil || pendingTarget != nil }

    public struct PendingPower: Codable, Equatable, Sendable {
        public let watts: Int
        public let charger: BikeChargerType
        public let revision: UUID

        public init(watts: Int, charger: BikeChargerType, revision: UUID) {
            self.watts = watts
            self.charger = charger
            self.revision = revision
        }
    }

    public struct PendingTarget: Codable, Equatable, Sendable {
        public let percent: Int
        public let revision: UUID

        public init(percent: Int, revision: UUID) {
            self.percent = percent
            self.revision = revision
        }
    }
}
