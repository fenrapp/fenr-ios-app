import Foundation
@testable import RideHistory
import RideSessionDomain
import SettingsDomain
import Testing

@Suite("Ride history mapper")
struct RideHistoryMapperTests {
    private let mapper = RideHistoryMapper(
        locale: Locale(identifier: "en_US"),
        measurementMapperFactory: RideHistoryMeasurementMapperFactory(),
        statisticsAggregator: RideTripStatisticsAggregator()
    )

    @Test("Maps summary rows and imperial measurements")
    func mapsList() {
        let trips = [
            RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000), distance: 10),
            RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 1_000), distance: 20)
        ]

        let state = mapper.mapList(trips: trips, measurementSystem: .imperial)

        #expect(state.status == .loaded)
        #expect(state.summary?.rideCountText == "2 rides")
        #expect(state.summary?.distanceText.contains("mi") == true)
        #expect(state.rides.first?.distanceText.contains("mi") == true)
        #expect(state.rides.first?.efficiencyText.contains("Wh/mi") == true)
        #expect(state.daySections.count == 1)
        #expect(state.daySections.first?.rides.count == 2)
    }

    @Test("Compares only with preceding rides and requires three samples")
    func mapsRecentComparisons() {
        let baseDate = Date(timeIntervalSince1970: 10_000)
        let newer = RideHistoryFixtures.trip(startedAt: baseDate.addingTimeInterval(1_000), efficiency: 200)
        let selected = RideHistoryFixtures.trip(startedAt: baseDate, efficiency: 80)
        let older = (1 ... 11).map { index in
            RideHistoryFixtures.trip(
                startedAt: baseDate.addingTimeInterval(-Double(index * 1_000)),
                efficiency: index == 11 ? 1_000 : 100
            )
        }

        let state = mapper.mapDetail(
            trip: selected,
            history: [newer, selected] + older,
            measurementSystem: .metric
        )

        let efficiency = state.comparisons.first { $0.id == "efficiency" }
        #expect(efficiency?.value == "+20%")
        #expect(efficiency?.detail == "more efficient")
        #expect(efficiency?.emphasis == .positive)

        let insufficient = mapper.mapDetail(
            trip: selected,
            history: [selected] + Array(older.prefix(2)),
            measurementSystem: .metric
        )
        #expect(insufficient.comparisons.isEmpty)
    }

    @Test("Maps battery and efficiency charts from detailed buckets")
    func mapsEnergyCharts() {
        let date = Date(timeIntervalSince1970: 5_000)
        let trip = RideHistoryFixtures.trip(
            startedAt: date,
            buckets: RideHistoryFixtures.buckets(startedAt: date)
        )

        let state = mapper.mapDetail(
            trip: trip,
            history: [trip],
            measurementSystem: .metric
        )

        #expect(state.batteryPoints.count == 4)
        #expect(state.efficiencyPoints.count == 4)
        let batteryMetric = state.energyMetrics.first { $0.id == "batteryChange" }
        #expect(batteryMetric?.value == "90% → 84%")
        #expect(batteryMetric?.detail == "6 percentage points used")
        #expect(state.distanceUnit == "km")
        #expect(state.efficiencyUnit == "Wh/km")
        #expect(state.overviewMetrics.first { $0.id == "duration" }?.iconTone == .accent)
        #expect(state.overviewMetrics.first { $0.id == "maximumSpeed" }?.iconTone == .accent)
        #expect(state.energyMetrics.first { $0.id == "recovered" }?.iconTone == .positive)
        #expect(state.energyMetrics.first { $0.id == "coverage" }?.iconTone == .informational)
    }

    @Test("Bounds chart marks for long rides while retaining endpoints and peaks")
    func downsamplesLongRideCharts() {
        let date = Date(timeIntervalSince1970: 6_000)
        let spikeIndex = 217
        let buckets = RideHistoryFixtures.denseBuckets(
            startedAt: date,
            count: 500,
            spikeIndex: spikeIndex
        )
        let trip = RideHistoryFixtures.trip(startedAt: date, buckets: buckets)

        let state = mapper.mapDetail(
            trip: trip,
            history: [trip],
            measurementSystem: .metric
        )

        #expect(state.batteryPoints.count <= 120)
        #expect(state.efficiencyPoints.count <= 120)
        #expect(state.batteryPoints.first?.id == buckets.first?.id)
        #expect(state.batteryPoints.last?.id == buckets.last?.id)
        #expect(state.efficiencyPoints.first?.id == buckets.first?.id)
        #expect(state.efficiencyPoints.last?.id == buckets.last?.id)
        #expect(state.efficiencyPoints.contains(where: { $0.id == buckets[spikeIndex].id }))
        #expect(state.efficiencyPoints.map(\.distance) == state.efficiencyPoints.map(\.distance).sorted())
    }

    @Test("Omits efficiency comparison when electrical coverage is partial")
    func excludesPartialEfficiency() {
        let date = Date(timeIntervalSince1970: 9_000)
        let selected = RideHistoryFixtures.trip(startedAt: date, coverage: 0.2)
        let older = (1 ... 4).map {
            RideHistoryFixtures.trip(startedAt: date.addingTimeInterval(-Double($0 * 1_000)))
        }

        let state = mapper.mapDetail(
            trip: selected,
            history: [selected] + older,
            measurementSystem: .metric
        )

        #expect(state.comparisons.contains(where: { $0.id == "efficiency" }) == false)
    }
}

extension RideHistoryMapperTests {
    @Test("History summary weights average speed by observed time and retains the peak speed")
    func summarizesSpeedAndExplicitDuration() {
        let trips = [
            RideHistoryFixtures.trip(
                startedAt: .distantPast, duration: 600, averageSpeed: 20, maximumSpeed: 45
            ),
            RideHistoryFixtures.trip(
                startedAt: .distantPast, duration: 1_800, averageSpeed: 60, maximumSpeed: 90
            )
        ]
        let metric = mapper.mapList(trips: trips, measurementSystem: .metric)
        #expect(metric.summary?.averageSpeedText == "50 km/h")
        #expect(metric.summary?.maximumSpeedText == "90 km/h")
        #expect(metric.summary?.durationText.contains("40") == true)
        #expect(metric.summary?.durationText.contains("min") == true)
        let imperial = mapper.mapList(trips: trips, measurementSystem: .imperial)
        #expect(imperial.summary?.averageSpeedText == "31 mph")
        #expect(imperial.summary?.maximumSpeedText == "56 mph")
        #expect(mapper.mapList(trips: [], measurementSystem: .metric).summary == nil)
    }
}
