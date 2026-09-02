import RideSessionDomain

extension RideHistoryMapper {
    func comparisons(
        trip: RideTrip,
        baseline: [RideTrip],
        efficiencyScale: Double
    ) -> [RideHistoryDetailViewState.Comparison] {
        var result = basicComparisons(trip: trip, baseline: baseline)
        if let efficiency = efficiencyComparison(
            trip: trip,
            baseline: baseline,
            scale: efficiencyScale
        ) {
            result.append(efficiency)
        }
        if let recovery = recoveryComparison(trip: trip, baseline: baseline) {
            result.append(recovery)
        }
        return result
    }

    func comparisonBaseline(for trip: RideTrip, in history: [RideTrip]) -> [RideTrip] {
        guard let index = history.firstIndex(where: { $0.id == trip.id }) else { return [] }
        return Array(history.dropFirst(index + 1).prefix(Constants.comparisonLimit))
    }

    func recoveryShare(_ trip: RideTrip) -> Double? {
        guard let consumed = validPositive(trip.consumedEnergyWattHours),
              trip.recoveredEnergyWattHours.isFinite,
              trip.recoveredEnergyWattHours >= .zero else { return nil }
        return trip.recoveredEnergyWattHours / consumed
    }
}

private extension RideHistoryMapper {
    func basicComparisons(
        trip: RideTrip,
        baseline: [RideTrip]
    ) -> [RideHistoryDetailViewState.Comparison] {
        let inputs = [
            PercentComparisonInput(
                id: "distance",
                label: String(localized: .rideHistoryMetricDistance),
                value: validPositive(trip.distanceKilometers),
                baseline: baseline.compactMap { validPositive($0.distanceKilometers) },
                increaseText: String(localized: .rideHistoryComparisonFarther),
                decreaseText: String(localized: .rideHistoryComparisonShorter)
            ),
            PercentComparisonInput(
                id: "duration",
                label: String(localized: .rideHistoryMetricRideTime),
                value: validPositive(trip.elapsedSeconds),
                baseline: baseline.compactMap { validPositive($0.elapsedSeconds) },
                increaseText: String(localized: .rideHistoryComparisonLonger),
                decreaseText: String(localized: .rideHistoryComparisonShorter)
            ),
            PercentComparisonInput(
                id: "averageSpeed",
                label: String(localized: .rideHistoryMetricAverageSpeed),
                value: validPositive(trip.averageSpeedKilometersPerHour),
                baseline: baseline.compactMap { validPositive($0.averageSpeedKilometersPerHour) },
                increaseText: String(localized: .rideHistoryComparisonFaster),
                decreaseText: String(localized: .rideHistoryComparisonSlower)
            )
        ]
        return inputs.compactMap(percentComparison)
    }

    func percentComparison(_ input: PercentComparisonInput) -> RideHistoryDetailViewState.Comparison? {
        guard let value = input.value,
              input.baseline.count >= Constants.minimumComparisonSamples,
              let baselineAverage = average(input.baseline) else { return nil }
        let difference = (value - baselineAverage) / baselineAverage * 100
        return .init(
            id: input.id,
            label: input.label,
            value: signedPercent(difference),
            detail: comparisonDetail(
                difference,
                positiveText: input.increaseText,
                negativeText: input.decreaseText
            ),
            emphasis: .neutral
        )
    }

    func efficiencyComparison(
        trip: RideTrip,
        baseline: [RideTrip],
        scale: Double
    ) -> RideHistoryDetailViewState.Comparison? {
        let selected = eligibleEfficiency(trip).map { $0 * scale }
        let values = baseline.compactMap(eligibleEfficiency).map { $0 * scale }
        guard let selected,
              values.count >= Constants.minimumComparisonSamples,
              let baselineAverage = average(values) else { return nil }
        let improvement = (baselineAverage - selected) / baselineAverage * 100
        return .init(
            id: "efficiency",
            label: String(localized: .rideHistoryMetricEfficiency),
            value: signedPercent(improvement),
            detail: comparisonDetail(
                improvement,
                positiveText: String(localized: .rideHistoryComparisonMoreEfficient),
                negativeText: String(localized: .rideHistoryComparisonLessEfficient)
            ),
            emphasis: comparisonEmphasis(improvement)
        )
    }

    func recoveryComparison(
        trip: RideTrip,
        baseline: [RideTrip]
    ) -> RideHistoryDetailViewState.Comparison? {
        let values = baseline.compactMap(recoveryShare)
        guard let selected = recoveryShare(trip),
              values.count >= Constants.minimumComparisonSamples,
              let baselineAverage = average(values) else { return nil }
        let percentagePoints = (selected - baselineAverage) * 100
        return .init(
            id: "recovery",
            label: String(localized: .rideHistoryMetricRegeneration),
            value: signedValue(percentagePoints, suffix: " pp"),
            detail: comparisonDetail(
                percentagePoints,
                positiveText: String(localized: .rideHistoryComparisonMoreRecovered),
                negativeText: String(localized: .rideHistoryComparisonLessRecovered)
            ),
            emphasis: comparisonEmphasis(percentagePoints)
        )
    }

    func eligibleEfficiency(_ trip: RideTrip) -> Double? {
        guard trip.isEfficiencyEligibleForHistory else { return nil }
        return trip.efficiencyWattHoursPerKilometer.flatMap(validPositive)
    }

    func signedPercent(_ value: Double) -> String {
        signedValue(value, suffix: "%")
    }

    func signedValue(_ value: Double, suffix: String) -> String {
        let rounded = value.rounded()
        let normalized = rounded == .zero ? Double.zero : rounded
        let prefix = normalized > .zero ? "+" : ""
        return prefix + format(normalized, fractionDigits: 0) + suffix
    }

    func comparisonDetail(_ value: Double, positiveText: String, negativeText: String) -> String {
        if abs(value) < Constants.equalComparisonThreshold {
            return String(localized: .rideHistoryComparisonRecentAverage)
        }
        return value > .zero ? positiveText : negativeText
    }

    func comparisonEmphasis(_ value: Double) -> RideHistoryDetailViewState.Comparison.Emphasis {
        if abs(value) < Constants.equalComparisonThreshold { return .neutral }
        return value > .zero ? .positive : .negative
    }

    func validPositive(_ value: Double) -> Double? {
        value.isFinite && value > .zero ? value : nil
    }

    func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let result = values.reduce(.zero, +) / Double(values.count)
        return validPositive(result)
    }

    struct PercentComparisonInput {
        let id: String
        let label: String
        let value: Double?
        let baseline: [Double]
        let increaseText: String
        let decreaseText: String
    }
}
