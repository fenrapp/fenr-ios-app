import RideSession
import RideSessionDomain
import SettingsDomain

struct RangeCardMappingInput: Equatable {
    private let vehicleIdentity: RideVehicleIdentity
    private let measurementSystem: MeasurementSystem
    private let batteryStateOfChargePercent: Int?
    private let batteryCapacityWattHours: Double
    private let trip: RideTrip?
    let historyIsLoading: Bool
    let historyReadFailed: Bool
    let hasLoadedHistory: Bool

    init(
        snapshot: RideSessionSnapshot, historyIsLoading: Bool,
        historyReadFailed: Bool, hasLoadedHistory: Bool
    ) {
        vehicleIdentity = snapshot.vehicleIdentity
        measurementSystem = snapshot.measurementSystem
        batteryStateOfChargePercent = snapshot.batteryStateOfChargePercent
        batteryCapacityWattHours = snapshot.batteryCapacityWattHours
        trip = snapshot.trip
        self.historyIsLoading = historyIsLoading
        self.historyReadFailed = historyReadFailed
        self.hasLoadedHistory = hasLoadedHistory
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.historyIsLoading == rhs.historyIsLoading
            && lhs.historyReadFailed == rhs.historyReadFailed
            && lhs.hasLoadedHistory == rhs.hasLoadedHistory
            && lhs.vehicleIdentity == rhs.vehicleIdentity
            && lhs.measurementSystem == rhs.measurementSystem
            && lhs.batteryStateOfChargePercent == rhs.batteryStateOfChargePercent
            && lhs.batteryCapacityWattHours == rhs.batteryCapacityWattHours
            && sameTripPresentation(lhs.trip, rhs.trip)
    }

    private static func sameTripPresentation(_ lhs: RideTrip?, _ rhs: RideTrip?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (lhs?, rhs?):
            return lhs.id == rhs.id
                && lhs.distanceKilometers == rhs.distanceKilometers
                && lhs.maximumDischargePowerWatts == rhs.maximumDischargePowerWatts
                && lhs.maximumRegenerationPowerWatts == rhs.maximumRegenerationPowerWatts
                && lhs.energyBuckets.elementsEqual(rhs.energyBuckets, by: sameBucketPresentation)
        default: return false
        }
    }

    private static func sameBucketPresentation(_ lhs: RideEnergyBucket, _ rhs: RideEnergyBucket) -> Bool {
        lhs.id == rhs.id
            && lhs.startDistanceKilometers == rhs.startDistanceKilometers
            && lhs.endDistanceKilometers == rhs.endDistanceKilometers
            && lhs.stateOfChargePercent == rhs.stateOfChargePercent
            && lhs.consumedEnergyWattHours == rhs.consumedEnergyWattHours
            && lhs.recoveredEnergyWattHours == rhs.recoveredEnergyWattHours
    }
}
