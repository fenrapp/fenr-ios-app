import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain

public struct RangeCardMapper: Sendable {
    private let locale: Locale
    private let estimator: RideRangeEstimator

    public init(locale: Locale, estimator: RideRangeEstimator) {
        self.locale = locale
        self.estimator = estimator
    }

    public func map(
        snapshot: RideSessionSnapshot,
        historicalTrips: [RideTrip],
        historyIsLoading: Bool
    ) -> DashboardRangeViewData {
        let usesMiles = snapshot.measurementSystem.resolved(for: locale) == .us
        let estimate = estimator.estimate(
            trip: snapshot.trip,
            historicalTrips: historicalTrips,
            stateOfChargePercent: snapshot.batteryStateOfChargePercent,
            batteryCapacityWattHours: snapshot.batteryCapacityWattHours
        )
        let buckets = recentBuckets(snapshot.trip?.energyBuckets ?? [])
        let distanceScale = usesMiles ? 1 / Constants.kilometersPerMile : 1
        let efficiencyScale = usesMiles ? Constants.kilometersPerMile : 1
        let tripDistance = snapshot.trip?.distanceKilometers ?? .zero
        let startDistance = buckets.first?.startDistanceKilometers ?? tripDistance
        let range = estimate.estimatedRangeKilometers.map { $0 * distanceScale }
        let rangeText = formatDistance(range)
        let distanceUnitText = usesMiles ? "mi" : "km"

        return DashboardRangeViewData(
            rangeText: rangeText,
            distanceUnitText: distanceUnitText,
            summary: range.map { _ in
                .init(
                    text: "\(rangeText) \(distanceUnitText)",
                    accessibilityLabel: "Estimated range \(rangeText) \(distanceUnitText)"
                )
            },
            status: status(estimate.confidence),
            typicalRangeText: formatDistance(estimate.typicalRangeKilometers.map { $0 * distanceScale }),
            currentRangeText: formatDistance(estimate.currentRangeKilometers.map { $0 * distanceScale }),
            batteryText: snapshot.batteryStateOfChargePercent.map { "\($0)%" } ?? "—",
            remainingEnergyText: formatEnergy(estimate.remainingEnergyWattHours),
            typicalEfficiency: estimate.typicalEfficiencyWattHoursPerKilometer.map { $0 * efficiencyScale },
            consumptionPoints: buckets.compactMap { bucket in
                guard let efficiency = bucket.efficiencyWattHoursPerKilometer else { return nil }
                return .init(
                    id: bucket.id,
                    distance: (bucket.endDistanceKilometers - startDistance) * distanceScale,
                    efficiency: efficiency * efficiencyScale
                )
            },
            batteryPoints: buckets.compactMap { bucket in
                guard let percentage = bucket.stateOfChargePercent else { return nil }
                return .init(
                    id: bucket.id,
                    distance: (bucket.endDistanceKilometers - startDistance) * distanceScale,
                    percentage: Double(percentage)
                )
            },
            peakDischargeText: formatPower(snapshot.trip?.maximumDischargePowerWatts),
            peakRegenerationText: formatPower(snapshot.trip?.maximumRegenerationPowerWatts),
            isLoadingHistory: historyIsLoading
        )
    }
}

private extension RangeCardMapper {
    func recentBuckets(_ buckets: [RideEnergyBucket]) -> [RideEnergyBucket] {
        var result: [RideEnergyBucket] = []
        var distance = 0.0
        for bucket in buckets.reversed() where bucket.distanceKilometers > .zero {
            result.append(bucket)
            distance += bucket.distanceKilometers
            if distance >= Constants.chartWindowKilometers { break }
        }
        return result.reversed()
    }

    func formatDistance(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= .zero else { return "—" }
        return value.formatted(.number.locale(locale).precision(.fractionLength(value < 10 ? 1 : 0)))
    }

    func formatEnergy(_ wattHours: Double) -> String {
        guard wattHours.isFinite, wattHours > .zero else { return "—" }
        return (wattHours / 1_000).formatted(.number.locale(locale).precision(.fractionLength(1))) + " kWh"
    }

    func formatPower(_ watts: Double?) -> String {
        guard let watts, watts.isFinite, watts > .zero else { return "—" }
        return (watts / 1_000).formatted(.number.locale(locale).precision(.fractionLength(1))) + " kW"
    }

    func status(_ confidence: RideRangeEstimate.Confidence) -> DashboardRangeViewData.Status {
        switch confidence {
        case .learning: .learning
        case .adapting: .adapting
        case .stable: .stable
        }
    }

    enum Constants {
        static let kilometersPerMile = 1.609_344
        static let chartWindowKilometers = 10.0
    }
}
