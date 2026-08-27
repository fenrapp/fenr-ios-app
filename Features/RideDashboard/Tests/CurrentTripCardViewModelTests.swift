import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain
import SettingsDomain
import Testing
import TestSupport

@Suite("Current trip card view model")
@MainActor
struct CurrentTripCardViewModelTests {
    @Test("Does not publish while hidden and catches up when visible")
    func publishesOnlyWhileVisible() async {
        let fixture = makeFixture()
        let trip = makeTrip(maximumSpeed: 42)
        await fixture.session.send(.init(trip: trip, vehicleIdentity: trip.vehicleIdentity))

        #expect(!fixture.viewModel.viewState.isActive)

        fixture.viewModel.setIsVisible(true)
        #expect(await waitUntil {
            fixture.viewModel.viewState.isActive
                && fixture.viewModel.viewState.maximumSpeed.valueText == "42"
        })

        fixture.viewModel.setIsVisible(false)
        await fixture.session.send(.init(
            trip: makeTrip(maximumSpeed: 67),
            vehicleIdentity: trip.vehicleIdentity
        ))
        await Task.yield()
        #expect(fixture.viewModel.viewState.maximumSpeed.valueText == "42")

        fixture.viewModel.setIsVisible(true)
        #expect(await waitUntil { fixture.viewModel.viewState.maximumSpeed.valueText == "67" })
    }

    @Test("Forwards reset and pause commands to the shared session")
    func forwardsCommands() async {
        let fixture = makeFixture()

        fixture.viewModel.togglePauseCurrentTrip()
        fixture.viewModel.resetCurrentTrip()

        #expect(await waitUntil {
            let pauseCommands = await fixture.session.pauseCommands()
            let resetCommands = await fixture.session.resetCommands()
            return pauseCommands == 1 && resetCommands == 1
        })
    }

    @Test("Serializes pause and reset commands")
    func serializesCommands() async {
        let session = TestRideSessionService(pauseCommandDelay: .milliseconds(20))
        let fixture = makeFixture(session: session)

        fixture.viewModel.togglePauseCurrentTrip()
        fixture.viewModel.resetCurrentTrip()

        #expect(await waitUntil {
            await session.commands() == [.togglePause, .reset]
        })
    }

    @Test("Uses the resolved source and GPS availability from the session")
    func usesSessionSpeedSource() async {
        let fixture = makeFixture()
        fixture.viewModel.setIsVisible(true)
        let trip = makeTrip(maximumSpeed: 67)

        await fixture.session.send(.init(
            trip: trip,
            vehicleIdentity: trip.vehicleIdentity,
            resolvedSpeedKilometersPerHour: 67,
            speedSource: .gps,
            isGPSAvailable: true
        ))

        #expect(await waitUntil {
            fixture.viewModel.viewState.speedSourceIndicator?.text == "GPS"
        })
    }

    private func makeFixture(
        session: TestRideSessionService = .init()
    ) -> Fixture {
        return Fixture(
            viewModel: CurrentTripCardViewModel(
                session: session,
                mapper: RideDashboardMapperFactory.makeCurrentTripMapper(
                    locale: Locale(identifier: "en_GB")
                )
            ),
            session: session
        )
    }

    private func makeTrip(maximumSpeed: Double) -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            maximumSpeedKilometersPerHour: maximumSpeed
        )
    }

    private struct Fixture {
        let viewModel: CurrentTripCardViewModel
        let session: TestRideSessionService
    }
}
