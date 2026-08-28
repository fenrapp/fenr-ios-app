import MeasurementPresentation
import RideSessionDomain

extension RideHistoryMapper {
    func energyMetrics(
        _ trip: RideTrip,
        efficiencyScale: Double,
        unit: String
    ) -> [RideHistoryDetailViewState.Metric] {
        var metrics = [
            metric(id: "used", label: "Energy Used", value: formatEnergy(trip.consumedEnergyWattHours)),
            metric(id: "recovered", label: "Recovered", value: formatEnergy(trip.recoveredEnergyWattHours)),
            metric(id: "net", label: "Net Energy", value: formatEnergy(trip.netEnergyWattHours))
        ]
        if let efficiency = trip.efficiencyWattHoursPerKilometer, efficiency.isFinite {
            metrics.append(metric(
                id: "efficiency",
                label: "Efficiency",
                value: format(efficiency * efficiencyScale, fractionDigits: abs(efficiency) < 10 ? 1 : 0)
                    + " \(unit)",
                detail: trip.hasSufficientElectricalCoverage ? nil : "Partial electrical coverage"
            ))
        }
        if let batteryMetric = batteryMetric(trip.energyBuckets) {
            metrics.append(batteryMetric)
        }
        metrics.append(metric(
            id: "coverage",
            label: "Power Coverage",
            value: format(trip.electricalCoverage * 100, fractionDigits: 0) + "%"
        ))
        if let recovery = recoveryShare(trip) {
            metrics.append(metric(
                id: "recoveryShare",
                label: "Energy Recovered",
                value: format(recovery * 100, fractionDigits: 0) + "%",
                detail: "of energy used"
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
            detail = "\(-change) percentage points used"
        } else if change > .zero {
            detail = "\(change) percentage points gained"
        } else {
            detail = "No recorded change"
        }
        return metric(
            id: "batteryChange",
            label: "Battery",
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
                label: "Peak Use",
                watts: trip.maximumDischargePowerWatts,
                measurementMapper: measurementMapper
            ),
            powerMetric(
                id: "peakRegen",
                label: "Peak Regen",
                watts: trip.maximumRegenerationPowerWatts,
                measurementMapper: measurementMapper
            )
        ].compactMap { $0 }
    }

    func dynamicsMetrics(_ trip: RideTrip) -> [RideHistoryDetailViewState.Metric] {
        let values = [
            ("leftLean", "Maximum Left Lean", trip.maximumLeftLeanDegrees),
            ("rightLean", "Maximum Right Lean", trip.maximumRightLeanDegrees),
            ("uphillPitch", "Maximum Uphill", trip.maximumUphillPitchDegrees),
            ("downhillPitch", "Maximum Downhill", trip.maximumDownhillPitchDegrees)
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
