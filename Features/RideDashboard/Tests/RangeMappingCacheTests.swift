import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain
import Testing

struct RangeMappingCacheTests {
    @Test("IMU, time, speed and live power updates reuse the exact range presentation")
    func irrelevantSamplesReuseMapping() {
        let mapper = RangeCardMapper(locale: Locale(identifier: "en_GB"), estimator: .init())
        let trips = [DashboardHistoryCardData.trip()]
        let recorder = DashboardMapperCallRecorder()
        var cache = DashboardPresentationCache<RangeCardMappingInput, DashboardRangeViewData>()
        for snapshot in [RangeMappingFixtures.snapshot(), RangeMappingFixtures.irrelevantChanges] {
            let result = cache.value(for: input(snapshot)) {
                recorder.record("range")
                return mapper.map(snapshot: snapshot, historicalTrips: trips, historyIsLoading: false)
            }
            #expect(result == mapper.map(snapshot: snapshot, historicalTrips: trips, historyIsLoading: false))
        }
        #expect(recorder.count("range") == 1)
    }

    @Test("Every consumed trip or chart field invalidates mapping", arguments: RangeMappingFixtures.TripChange.allCases)
    func tripChangesRemainEquivalent(change: RangeMappingFixtures.TripChange) {
        let original = RangeMappingFixtures.snapshot()
        let changed = RangeMappingFixtures.snapshot(trip: RangeMappingFixtures.trip(change))
        let mapper = RangeCardMapper(locale: Locale(identifier: "en_GB"), estimator: .init())
        var cache = DashboardPresentationCache<RangeCardMappingInput, DashboardRangeViewData>()
        let recorder = DashboardMapperCallRecorder()
        for snapshot in [original, changed] {
            let result = cache.value(for: input(snapshot)) {
                recorder.record("range")
                return mapper.map(snapshot: snapshot, historicalTrips: [], historyIsLoading: false)
            }
            #expect(result == mapper.map(snapshot: snapshot, historicalTrips: [], historyIsLoading: false))
        }
        #expect(recorder.count("range") == (change == .none || change == .timestamps ? 1 : 2))
    }

    @Test("Vehicle, units, charge, capacity and history state all invalidate the cache")
    func relevantConfigurationAndHistoryInvalidate() {
        let original = RangeMappingFixtures.snapshot()
        let snapshots = [
            RangeMappingFixtures.snapshot(vin: "FENRTEST000000002"),
            RangeMappingFixtures.snapshot(units: .imperial), RangeMappingFixtures.snapshot(charge: 40),
            RangeMappingFixtures.snapshot(capacity: 8_000), RangeMappingFixtures.snapshot(trip: nil)
        ]
        for changed in snapshots { #expect(input(original) != input(changed)) }
        let variants = [
            RangeCardMappingInput(snapshot: original, historyIsLoading: true,
                                  historyReadFailed: false, hasLoadedHistory: true),
            RangeCardMappingInput(snapshot: original, historyIsLoading: false,
                                  historyReadFailed: true, hasLoadedHistory: true),
            RangeCardMappingInput(snapshot: original, historyIsLoading: false,
                                  historyReadFailed: false, hasLoadedHistory: false)
        ]
        for changed in variants { #expect(input(original) != changed) }
    }

    private func input(_ snapshot: RideSessionSnapshot) -> RangeCardMappingInput {
        .init(snapshot: snapshot, historyIsLoading: false,
              historyReadFailed: false, hasLoadedHistory: true)
    }
}
