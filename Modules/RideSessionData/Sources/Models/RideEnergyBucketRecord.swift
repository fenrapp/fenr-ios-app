import Foundation
import SwiftData

@Model
final class RideEnergyBucketRecord {
    @Attribute(.unique) var id: UUID
    var tripID: UUID
    var vehicleIdentityKind: String
    var vehicleIdentityValue: String
    var applicationSessionID: UUID
    var startedAt: Date
    var updatedAt: Date
    var startDistanceKilometers: Double
    var endDistanceKilometers: Double
    var stateOfChargePercent: Int?
    var consumedEnergyWattHours: Double
    var recoveredEnergyWattHours: Double

    init(
        id: UUID,
        tripID: UUID,
        vehicleIdentityKind: String,
        vehicleIdentityValue: String,
        applicationSessionID: UUID,
        startedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.tripID = tripID
        self.vehicleIdentityKind = vehicleIdentityKind
        self.vehicleIdentityValue = vehicleIdentityValue
        self.applicationSessionID = applicationSessionID
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        startDistanceKilometers = .zero
        endDistanceKilometers = .zero
        stateOfChargePercent = nil
        consumedEnergyWattHours = .zero
        recoveredEnergyWattHours = .zero
    }
}
