import MeasurementPresentation
import RideSessionDomain

extension RideHistoryMapper {
    func energyMetrics(
        _ trip: RideTrip,
        efficiencyScale: Double,
        unit: String
    ) -> [RideHistoryDetailViewState.Metric] {
        var metrics = [
            metric(
                id: "used",
                label: String(localized: .rideHistoryMetricEnergyUsed),
                value: formatEnergy(trip.consumedEnergyWattHours)
            ),
            metric(
                id: "recovered",
                label: String(localized: .rideHistoryMetricRecovered),
                value: formatEnergy(trip.recoveredEnergyWattHours)
            ),
            metric(
                id: "net",
                label: String(localized: .rideHistoryMetricNetEnergy),
                value: formatEnergy(trip.netEnergyWattHours)
            )
        ]
        if let efficiency = trip.efficiencyWattHoursPerKilometer, efficiency.isFinite {
            metrics.append(metric(
                id: "efficiency",
                label: String(localized: .rideHistoryMetricEfficiency),
                value: format(efficiency * efficiencyScale, fractionDigits: abs(efficiency) < 10 ? 1 : 0)
                    + " \(unit)",
                detail: trip.hasSufficientElectricalCoverage
                    ? nil
                    : String(localized: .rideHistoryPartialElectricalCoverage)
            ))
        }
        if let batteryMetric = batteryMetric(trip.energyBuckets) {
            metrics.append(batteryMetric)
        }
        metrics.append(metric(
            id: "coverage",
            label: String(localized: .rideHistoryMetricPowerCoverage),
            value: format(trip.electricalCoverage * 100, fractionDigits: 0) + "%"
        ))
        if let recovery = recoveryShare(trip) {
            metrics.append(metric(
                id: "recoveryShare",
                label: String(localized: .rideHistoryMetricEnergyRecovered),
                value: format(recovery * 100, fractionDigits: 0) + "%",
                detail: String(localized: .rideHistoryOfEnergyUsed)
            ))
        }
        return metrics
    }

    func batteryMetric(_ buckets: [RideEnergyBucket]) -> RideHistoryDetailViewState.Metric? {
        let values = buckets.compactMap { bucket -> Int? in
            guard let percentage = bucket.stateOfChargePercent,
                  0 ... 100 ~= percentage else { return nil }
            return percentage
        }
        guard values.count >= Constants.minimumChartPoints,
              let first = values.first,
              let last = values.last else { return nil }
        let change = last - first
        let detail: String
        if change < .zero {
            detail = String(localized: .rideHistoryBatteryPointsUsed(-change))
        } else if change > .zero {
            detail = String(localized: .rideHistoryBatteryPointsGained(change))
        } else {
            detail = String(localized: .rideHistoryBatteryNoRecordedChange)
        }
        return metric(
            id: "batteryChange",
            label: String(localized: .rideHistoryMetricBattery),
            value: "\(first)% → \(last)%",
            detail: detail
        )
    }

    func performanceMetrics(
        _ trip: RideTrip,
        measurementMapper: VehicleMeasurementMapper
    ) -> [RideHistoryDetailViewState.Metric] {
        [
            powerMetric(
                id: "peakUse",
                label: String(localized: .rideHistoryMetricPeakUse),
                watts: trip.maximumDischargePowerWatts,
                measurementMapper: measurementMapper
            ),
            powerMetric(
                id: "peakRegen",
                label: String(localized: .rideHistoryMetricPeakRegen),
                watts: trip.maximumRegenerationPowerWatts,
                measurementMapper: measurementMapper
            )
        ].compactMap { $0 }
    }

    func dynamicsMetrics(_ trip: RideTrip) -> [RideHistoryDetailViewState.Metric] {
        let values = [
            ("leftLean", String(localized: .rideHistoryMetricMaximumLeftLean), trip.maximumLeftLeanDegrees),
            ("rightLean", String(localized: .rideHistoryMetricMaximumRightLean), trip.maximumRightLeanDegrees),
            ("uphillPitch", String(localized: .rideHistoryMetricMaximumUphill), trip.maximumUphillPitchDegrees),
            ("downhillPitch", String(localized: .rideHistoryMetricMaximumDownhill), trip.maximumDownhillPitchDegrees)
        ]
        guard values.contains(where: { $0.2.isFinite && $0.2 > .zero }) else { return [] }
        return values.compactMap { id, label, value in
            guard value.isFinite, value >= .zero else { return nil }
            return metric(
                id: id,
                label: label,
                value: format(value, fractionDigits: 1) + "°"
            )
        }
    }

    func chartData(
        _ buckets: [RideEnergyBucket],
        measurementMapper: VehicleMeasurementMapper,
        efficiencyScale: Double
    ) -> (battery: [RideHistoryDetailViewState.ChartPoint], efficiency: [RideHistoryDetailViewState.ChartPoint]) {
        guard let startDistance = buckets.first?.startDistanceKilometers else { return ([], []) }
        let battery = buckets.compactMap { bucket -> RideHistoryDetailViewState.ChartPoint? in
            guard let percentage = bucket.stateOfChargePercent,
                  0 ... 100 ~= percentage,
                  let distance = chartDistance(
                      bucket.endDistanceKilometers - startDistance,
                      measurementMapper: measurementMapper
                  ) else { return nil }
            return .init(id: bucket.id, distance: distance, value: Double(percentage))
        }
        let efficiency = buckets.compactMap { bucket -> RideHistoryDetailViewState.ChartPoint? in
            guard let value = bucket.efficiencyWattHoursPerKilometer,
                  value.isFinite,
                  let distance = chartDistance(
                      bucket.endDistanceKilometers - startDistance,
                      measurementMapper: measurementMapper
                  ) else { return nil }
            return .init(id: bucket.id, distance: distance, value: value * efficiencyScale)
        }
        return (
            battery.count >= Constants.minimumChartPoints ? battery : [],
            efficiency.count >= Constants.minimumChartPoints ? efficiency : []
        )
    }

    private func chartDistance(
        _ kilometers: Double,
        measurementMapper: VehicleMeasurementMapper
    ) -> Double? {
        let distance = measurementMapper.distance(kilometers: max(kilometers, .zero)).value
        return distance.isFinite ? distance : nil
    }
}
