import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain

public struct RideNavigationRangeMapper: Sendable {
    private let estimator: RideRangeEstimator
    private let locale: Locale

    public init(estimator: RideRangeEstimator, locale: Locale) {
        self.estimator = estimator
        self.locale = locale
    }

    public func map(snapshot: RideSessionSnapshot, history: [RideTrip]) -> RideNavigationRangeState {
        let usesMiles = snapshot.measurementSystem.resolved(for: locale) == .us
        let unit = usesMiles ? "mi" : "km"
        guard snapshot.isCanonicalTelemetryAvailable,
              snapshot.batteryStateOfChargePercent != nil else {
            return RideNavigationRangeState(unit: unit)
        }
        let estimate = estimator.estimate(
            trip: snapshot.trip, historicalTrips: history,
            stateOfChargePercent: snapshot.batteryStateOfChargePercent,
            batteryCapacityWattHours: snapshot.batteryCapacityWattHours
        )
        guard let kilometers = estimate.estimatedRangeKilometers,
              kilometers.isFinite, kilometers >= .zero else {
            return RideNavigationRangeState(unit: unit)
        }
        let distance = usesMiles ? kilometers / Constants.kilometersPerMile : kilometers
        return RideNavigationRangeState(
            value: distance.formatted(.number.locale(locale).precision(.fractionLength(distance < 10 ? 1 : 0))),
            unit: unit
        )
    }

    private enum Constants {
        static let kilometersPerMile = 1.609_344
    }
}
