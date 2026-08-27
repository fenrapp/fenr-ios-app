import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Efficiency card")
struct EfficiencyCardTests {
    @Test("Maps signed net energy and partial coverage")
    func mapsLiveEfficiency() {
        let trip = RideTrip(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            distanceKilometers: 2,
            consumedEnergyWattHours: 100,
            recoveredEnergyWattHours: 20,
            electricalObservedSeconds: 80,
            electricalExpectedSeconds: 100
        )
        let state = EfficiencyCardMapper(locale: Locale(identifier: "en_GB")).map(
            snapshot: .init(
                trip: trip,
                vehicleIdentity: trip.vehicleIdentity,
                livePowerSamples: [
                    .init(date: .distantPast, powerWatts: 4_000),
                    .init(date: .distantPast.addingTimeInterval(1), powerWatts: -2_000)
                ]
            ),
            trendTrips: [],
            trendIsLoading: false,
            measurementSystem: .metric
        )

        #expect(state.valueText == "40")
        #expect(state.status == .partial)
        #expect(state.powerPoints.map(\.kilowatts) == [4, -2])
        #expect(state.usedEnergyText == "100 Wh")
        #expect(state.recoveredEnergyText == "20 Wh")
    }

    @Test("Loads SwiftData history only after selecting trend and caches it")
    func loadsTrendLazily() async {
        let tripRepository = CurrentTripCardTripRepository(completedTrips: [eligibleTrip()])
        let session = TestRideSessionService(snapshot: .init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin)
        ))
        let viewModel = EfficiencyCardViewModel(
            useCases: .init(
                loadTrend: .init(repository: tripRepository)
            ),
            mapper: .init(locale: Locale(identifier: "en_GB")),
            session: session
        )
        viewModel.setIsVisible(true, page: .live)
        try? await Task.sleep(for: .milliseconds(20))
        #expect(await tripRepository.loadCount() == 0)

        viewModel.setIsVisible(true, page: .trend)
        #expect(await waitUntil {
            await tripRepository.loadCount() == 1 && viewModel.viewState.trendPoints.count == 1
        })

        viewModel.setIsVisible(true, page: .live)
        viewModel.setIsVisible(true, page: .trend)
        await Task.yield()
        #expect(await tripRepository.loadCount() == 1)
    }

    @Test("Defers trend revisions while hidden and reloads when visible")
    func reloadsTrendRevisionWhenVisible() async {
        let tripRepository = CurrentTripCardTripRepository(completedTrips: [eligibleTrip()])
        let session = TestRideSessionService(snapshot: .init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin)
        ))
        let viewModel = EfficiencyCardViewModel(
            useCases: .init(loadTrend: .init(repository: tripRepository)),
            mapper: .init(locale: Locale(identifier: "en_GB")),
            session: session
        )
        viewModel.setIsVisible(true, page: .trend)
        #expect(await waitUntil { await tripRepository.loadCount() == 1 })

        viewModel.setIsVisible(false, page: .trend)
        await tripRepository.replaceCompletedTrips(with: [eligibleTrip(), eligibleTrip()])
        await session.send(.init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            historyRevision: 1
        ))
        await Task.yield()
        #expect(await tripRepository.loadCount() == 1)

        viewModel.setIsVisible(true, page: .trend)
        #expect(await waitUntil {
            await tripRepository.loadCount() == 2
                && viewModel.viewState.trendPoints.count == 2
        })
    }

    private func eligibleTrip() -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            endedAt: .distantPast,
            distanceKilometers: 2,
            consumedEnergyWattHours: 150,
            recoveredEnergyWattHours: 10,
            electricalObservedSeconds: 95,
            electricalExpectedSeconds: 100
        )
    }
}
