import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain
import Testing
import TestSupport

@MainActor
@Suite("Range card")
struct RangeCardTests {
    @Test("Maps adaptive range, consumption and battery charts")
    func mapsRangeCard() {
        let trip = activeTrip()
        let state = RangeCardMapper(
            locale: Locale(identifier: "en_GB"),
            estimator: RideRangeEstimator()
        ).map(
            snapshot: .init(
                trip: trip,
                vehicleIdentity: trip.vehicleIdentity,
                batteryStateOfChargePercent: 50,
                batteryCapacityWattHours: 7_200
            ),
            historicalTrips: [historicalTrip()],
            historyIsLoading: false
        )

        #expect(state.rangeText != "—")
        #expect(state.summary?.text == "51 km")
        #expect(state.batteryText == "50%")
        #expect(state.remainingEnergyText == "3.6 kWh")
        #expect(state.consumptionPoints.count == 1)
        #expect(state.batteryPoints.count == 1)
        #expect(state.peakDischargeText == "12.0 kW")
        #expect(state.peakRegenerationText == "4.0 kW")
    }

    @Test("Omits the dashboard summary until a range can be estimated")
    func omitsUnavailableSummary() {
        let state = RangeCardMapper(
            locale: Locale(identifier: "en_GB"),
            estimator: RideRangeEstimator()
        ).map(
            snapshot: .init(
                vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
                batteryStateOfChargePercent: 60,
                batteryCapacityWattHours: 7_200
            ),
            historicalTrips: [],
            historyIsLoading: false
        )

        #expect(state.rangeText == "—")
        #expect(state.summary == nil)
    }

    @Test("Keeps the visible range summary current without publishing the hidden card")
    func keepsSummaryCurrentWhileCardIsHidden() async {
        let repository = CurrentTripCardTripRepository(completedTrips: [historicalTrip()])
        let session = TestRideSessionService(snapshot: .init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            batteryStateOfChargePercent: 60,
            batteryCapacityWattHours: 7_200
        ))
        let viewModel = RangeCardViewModel(
            useCases: .init(loadHistory: .init(repository: repository)),
            mapper: .init(locale: Locale(identifier: "en_GB"), estimator: RideRangeEstimator()),
            session: session
        )

        await Task.yield()
        #expect(await repository.loadCount() == 0)
        viewModel.start()
        #expect(await waitUntil { await repository.loadCount() == 1 })
        #expect(await waitUntil { viewModel.summary != nil })
        #expect(viewModel.viewState == DashboardRangeViewData())

        await session.send(.init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            historyRevision: 1,
            batteryStateOfChargePercent: 50,
            batteryCapacityWattHours: 7_200
        ))
        #expect(await waitUntil { await repository.loadCount() == 2 })
        #expect(viewModel.viewState == DashboardRangeViewData())

        viewModel.setIsVisible(true)
        #expect(viewModel.viewState.summary != nil)
    }

    private func activeTrip() -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            distanceKilometers: 2,
            maximumDischargePowerWatts: 12_000,
            maximumRegenerationPowerWatts: 4_000,
            energyBuckets: [
                .init(
                    startedAt: .distantPast,
                    updatedAt: .distantFuture,
                    startDistanceKilometers: .zero,
                    endDistanceKilometers: 2,
                    stateOfChargePercent: 50,
                    consumedEnergyWattHours: 160,
                    recoveredEnergyWattHours: 20
                )
            ]
        )
    }

    private func historicalTrip() -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            endedAt: .distantPast,
            distanceKilometers: 10,
            consumedEnergyWattHours: 700,
            electricalObservedSeconds: 100,
            electricalExpectedSeconds: 100
        )
    }
}
