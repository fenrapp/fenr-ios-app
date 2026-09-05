import Foundation
import RideSessionDomain
import SettingsDomain

public struct RideHistoryMapper: Sendable {
    let locale: Locale
    let durationStyle: Duration.TimeFormatStyle
    let measurementMapperFactory: RideHistoryMeasurementMapperFactory
    let statisticsAggregator: RideTripStatisticsAggregator

    public init(
        locale: Locale,
        measurementMapperFactory: RideHistoryMeasurementMapperFactory,
        statisticsAggregator: RideTripStatisticsAggregator
    ) {
        self.locale = locale
        self.measurementMapperFactory = measurementMapperFactory
        self.statisticsAggregator = statisticsAggregator
        durationStyle = Duration.TimeFormatStyle(
            pattern: .hourMinute(padHourToLength: 2, roundSeconds: .towardZero)
        ).locale(locale)
    }

    public func mapList(
        trips: [RideTrip],
        measurementSystem: MeasurementSystem,
        deletingRideIDs: Set<UUID> = [],
        errorMessage: String? = nil
    ) -> RideHistoryViewState {
        guard !trips.isEmpty else {
            return .init(status: .empty, errorMessage: errorMessage)
        }
        let measurementMapper = makeMeasurementMapper(measurementSystem)
        let statistics = statisticsAggregator.aggregate(trips)
        let distance = measurementMapper.distance(kilometers: statistics.totalDistanceKilometers)
        let rideCountText = String(localized: .rideHistoryRideCount(rideCount: trips.count))
        let rows = trips.map {
            row($0, measurementMapper: measurementMapper, measurementSystem: measurementSystem)
        }
        return .init(
            status: .loaded,
            summary: .init(
                rideCountText: rideCountText,
                distanceText: format(distance.value, fractionDigits: distance.value < 100 ? 1 : 0)
                    + " \(distance.unit)",
                durationText: Duration.seconds(statistics.totalElapsedSeconds).formatted(
                    .units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale)
                ),
                averageSpeedText: speedText(measurementMapper.speed(
                    kilometersPerHour: statistics.averageSpeedKilometersPerHour
                )),
                maximumSpeedText: speedText(measurementMapper.speed(
                    kilometersPerHour: statistics.maximumSpeedKilometersPerHour
                ))
            ),
            daySections: daySections(from: rows),
            deletingRideIDs: deletingRideIDs,
            errorMessage: errorMessage
        )
    }

    func daySections(from rows: [RideHistoryViewState.Row]) -> [RideHistoryViewState.DaySection] {
        rows.reduce(into: []) { sections, row in
            if let last = sections.last, last.title == row.dateText {
                sections[sections.index(before: sections.endIndex)] = .init(
                    id: last.id,
                    title: last.title,
                    rides: last.rides + [row]
                )
            } else {
                sections.append(.init(id: row.dateText, title: row.dateText, rides: [row]))
            }
        }
    }

    public func mapDetail(
        trip: RideTrip,
        history: [RideTrip],
        measurementSystem: MeasurementSystem
    ) -> RideHistoryDetailViewState {
        let measurementMapper = makeMeasurementMapper(measurementSystem)
        let distance = measurementMapper.distance(kilometers: trip.distanceKilometers)
        let averageSpeed = measurementMapper.speed(kilometersPerHour: trip.averageSpeedKilometersPerHour)
        let maximumSpeed = measurementMapper.speed(kilometersPerHour: trip.maximumSpeedKilometersPerHour)
        let usesMiles = measurementSystem.resolved(for: locale) == .us
        let efficiencyUnit = usesMiles ? "Wh/mi" : "Wh/km"
        let efficiencyScale = usesMiles ? Constants.kilometersPerMile : 1
        let baseline = comparisonBaseline(for: trip, in: history)
        let chartData = chartData(
            trip.energyBuckets,
            measurementMapper: measurementMapper,
            efficiencyScale: efficiencyScale
        )

        return .init(
            status: .loaded,
            rideID: trip.id,
            title: trip.startedAt.formatted(
                .dateTime.locale(locale).weekday(.wide).month(.wide).day().year()
            ),
            subtitle: timeRange(trip),
            distanceText: distanceText(distance),
            overviewMetrics: [
                metric(
                    id: "duration",
                    label: String(localized: .rideHistoryMetricRideTime),
                    value: formatDuration(trip.elapsedSeconds)
                ),
                metric(
                    id: "averageSpeed",
                    label: String(localized: .rideHistoryMetricAverageSpeed),
                    value: speedText(averageSpeed)
                ),
                metric(
                    id: "maximumSpeed",
                    label: String(localized: .rideHistoryMetricMaximumSpeed),
                    value: speedText(maximumSpeed)
                )
            ],
            energyMetrics: energyMetrics(trip, efficiencyScale: efficiencyScale, unit: efficiencyUnit),
            performanceMetrics: performanceMetrics(trip, measurementMapper: measurementMapper),
            dynamicsMetrics: dynamicsMetrics(trip),
            comparisons: comparisons(trip: trip, baseline: baseline, efficiencyScale: efficiencyScale),
            comparisonDetail: baseline.count >= Constants.minimumComparisonSamples
                ? String(localized: .rideHistoryComparisonBaseline)
                : nil,
            batteryPoints: chartData.battery,
            efficiencyPoints: chartData.efficiency,
            distanceUnit: distance.unit,
            efficiencyUnit: efficiencyUnit
        )
    }
}
