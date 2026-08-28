import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain

public struct EfficiencyCardMapper: Sendable {
    private let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    public func map(
        snapshot: RideSessionSnapshot,
        trendTrips: [RideTrip],
        trendIsLoading: Bool,
        measurementSystem: MeasurementSystem
    ) -> DashboardEfficiencyViewData {
        let usesMiles = measurementSystem.resolved(for: locale) == .us
        let unit = usesMiles ? "Wh/mi" : "Wh/km"
        let trip = snapshot.trip
        let efficiency = trip?.efficiencyWattHoursPerKilometer.map {
            usesMiles ? $0 * Constants.kilometersPerMile : $0
        }
        let status: DashboardEfficiencyViewData.Status
        if efficiency == nil {
            status = .calculating
        } else if trip?.hasSufficientElectricalCoverage != true {
            status = .partial
        } else if efficiency ?? .zero < .zero {
            status = .netRecovery
        } else {
            status = .calculated
        }

        return DashboardEfficiencyViewData(
            valueText: efficiency.map(formatEfficiency) ?? "—",
            unitText: unit,
            status: status,
            usedEnergyText: formatEnergy(trip?.consumedEnergyWattHours ?? .zero),
            recoveredEnergyText: formatEnergy(trip?.recoveredEnergyWattHours ?? .zero),
            powerPoints: snapshot.livePowerSamples.map {
                let kilowatts = $0.powerWatts / 1_000
                return .init(
                    date: $0.date,
                    usedKilowatts: max(kilowatts, .zero),
                    regenKilowatts: max(-kilowatts, .zero)
                )
            },
            trendPoints: trendTrips.compactMap { trendPoint($0, usesMiles: usesMiles) },
            trendIsLoading: trendIsLoading,
            hasConfirmedVehicle: snapshot.vehicleIdentity.confirmedVIN != nil
        )
    }

    private func trendPoint(_ trip: RideTrip, usesMiles: Bool) -> DashboardEfficiencyViewData.TrendPoint? {
        guard let efficiency = trip.efficiencyWattHoursPerKilometer else { return nil }
        return .init(
            id: trip.id,
            date: trip.endedAt ?? trip.updatedAt,
            efficiency: usesMiles ? efficiency * Constants.kilometersPerMile : efficiency
        )
    }

    private func formatEfficiency(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(abs(value) < 10 ? 1 : 0))
        )
    }

    private func formatEnergy(_ wattHours: Double) -> String {
        if abs(wattHours) >= 1_000 {
            return (wattHours / 1_000).formatted(
                .number.locale(locale).precision(.fractionLength(1))
            ) + " kWh"
        }
        return wattHours.formatted(
            .number.locale(locale).precision(.fractionLength(0))
        ) + " Wh"
    }

    private enum Constants {
        static let kilometersPerMile = 1.609_344
    }
}
