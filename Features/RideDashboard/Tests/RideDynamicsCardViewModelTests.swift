@testable import RideDashboard
import Testing
import TestSupport

@MainActor
@Suite("Ride dynamics card view model")
struct RideDynamicsCardViewModelTests {
    @Test("Serializes location monitoring requests")
    func serializesLocationMonitoringRequests() async {
        let fixture = makeFixture()
        await fixture.vehicleSession.blockNextLocationRequest()

        fixture.viewModel.setIsVisible(true)
        #expect(await waitUntil {
            let requests = await fixture.vehicleSession.recordedLocationRequests()
            let pendingCount = await fixture.vehicleSession.pendingLocationRequestCount()
            return requests == [true] && pendingCount == 1
        })

        fixture.viewModel.setIsVisible(false)
        #expect(await fixture.vehicleSession.recordedLocationRequests() == [true])

        await fixture.vehicleSession.releaseNextLocationRequest()
        #expect(await waitUntil {
            await fixture.vehicleSession.recordedLocationRequests() == [true, false]
        })
    }

    @Test("Deinit releases location monitoring after a pending acquisition")
    func deinitWaitsForPendingLocationAcquisitionBeforeRelease() async {
        let rideSession = RideDynamicsTestRideSession()
        let vehicleSession = RideDynamicsTestVehicleSession()
        await vehicleSession.blockNextLocationRequest()
        var viewModel: RideDynamicsCardViewModel? = makeViewModel(
            rideSession: rideSession,
            vehicleSession: vehicleSession
        )

        viewModel?.setIsVisible(true)
        #expect(await waitUntil {
            let requests = await vehicleSession.recordedLocationRequests()
            let pendingCount = await vehicleSession.pendingLocationRequestCount()
            return requests == [true] && pendingCount == 1
        })

        viewModel = nil
        #expect(await vehicleSession.recordedLocationRequests() == [true])

        await vehicleSession.releaseNextLocationRequest()
        #expect(await waitUntil {
            await vehicleSession.recordedLocationRequests() == [true, false]
        })
    }

    @Test("Coalesces calibration while one request is in flight")
    func coalescesCalibrationWhileInFlight() async {
        let fixture = makeFixture()
        await fixture.vehicleSession.blockNextCalibration()
        fixture.viewModel.setIsVisible(true)
        #expect(await waitUntil { fixture.viewModel.viewState.canCalibrate })

        fixture.viewModel.calibrate()
        fixture.viewModel.calibrate()

        #expect(await waitUntil {
            await fixture.vehicleSession.recordedCalibrationRequestCount() == 1
        })
        await fixture.vehicleSession.releaseNextCalibration()
        #expect(await waitUntil {
            await fixture.vehicleSession.recordedCompletedCalibrationCount() == 1
        })
    }

    @Test("Allows calibration again after the previous request completes")
    func allowsCalibrationAgainAfterCompletion() async {
        let fixture = makeFixture()
        await fixture.vehicleSession.blockNextCalibration()
        fixture.viewModel.setIsVisible(true)
        #expect(await waitUntil { fixture.viewModel.viewState.canCalibrate })
        fixture.viewModel.calibrate()
        #expect(await waitUntil {
            await fixture.vehicleSession.recordedCalibrationRequestCount() == 1
        })

        await fixture.vehicleSession.releaseNextCalibration()
        #expect(await waitUntil {
            await fixture.vehicleSession.recordedCompletedCalibrationCount() == 1
        })
        #expect(await waitUntil {
            fixture.viewModel.calibrate()
            return await fixture.vehicleSession.recordedCalibrationRequestCount() == 2
        })
    }

    @Test("Preserves dynamics values while canonical telemetry recovers")
    func preservesPresentationDuringRecovery() async {
        let fixture = makeFixture()
        fixture.viewModel.setIsVisible(true)
        #expect(await fixture.rideSession.waitForSubscriber())
        await fixture.rideSession.send(.init(
            vehicleIdentity: .vin("FENRTEST000000001"),
            motion: .init(
                rollDegrees: -12,
                pitchDegrees: 4,
                availability: .available,
                observedAt: .init(timeIntervalSinceReferenceDate: 1)
            ),
            isCanonicalTelemetryAvailable: true
        ))
        #expect(await waitUntil {
            fixture.viewModel.viewState.leanDegrees == -12
                && fixture.viewModel.viewState.canCalibrate
        })

        await fixture.rideSession.send(.init(
            vehicleIdentity: .vin("FENRTEST000000001"),
            isCanonicalTelemetryAvailable: false
        ))
        #expect(await waitUntil { !fixture.viewModel.viewState.canCalibrate })
        #expect(fixture.viewModel.viewState.leanDegrees == -12)
        #expect(fixture.viewModel.viewState.pitchDegrees == 4)

        await fixture.rideSession.send(.init(
            vehicleIdentity: .vin("FENRTEST000000001"),
            motion: .init(
                rollDegrees: 7,
                pitchDegrees: -2,
                availability: .available,
                observedAt: .init(timeIntervalSinceReferenceDate: 2)
            ),
            isCanonicalTelemetryAvailable: true
        ))
        #expect(await waitUntil {
            fixture.viewModel.viewState.leanDegrees == 7
                && fixture.viewModel.viewState.pitchDegrees == -2
                && fixture.viewModel.viewState.canCalibrate
        })
    }

    @Test("Keeps the last live instrument through a transient missing IMU sample")
    func preservesLiveInstrumentDuringTransientUnavailableMotion() async {
        let fixture = makeFixture()
        fixture.viewModel.setIsVisible(true)
        #expect(await fixture.rideSession.waitForSubscriber())
        await fixture.rideSession.send(.init(
            vehicleIdentity: .vin("FENRTEST000000001"),
            motion: .init(
                rollDegrees: 12,
                pitchDegrees: -3,
                availability: .available,
                observedAt: .init(timeIntervalSinceReferenceDate: 1)
            ),
            isCanonicalTelemetryAvailable: true
        ))
        #expect(await waitUntil { fixture.viewModel.viewState.status == .live })

        await fixture.rideSession.send(.init(
            vehicleIdentity: .vin("FENRTEST000000001"),
            motion: .init(availability: .unavailable),
            isCanonicalTelemetryAvailable: true
        ))

        #expect(await waitUntil { !fixture.viewModel.viewState.canCalibrate })
        #expect(fixture.viewModel.viewState.status == .live)
        #expect(fixture.viewModel.viewState.leanDegrees == 12)
        #expect(fixture.viewModel.viewState.pitchDegrees == -3)
    }

    private func makeFixture() -> Fixture {
        let rideSession = RideDynamicsTestRideSession()
        let vehicleSession = RideDynamicsTestVehicleSession()
        return Fixture(
            viewModel: makeViewModel(
                rideSession: rideSession,
                vehicleSession: vehicleSession
            ),
            vehicleSession: vehicleSession,
            rideSession: rideSession
        )
    }

    private func makeViewModel(
        rideSession: RideDynamicsTestRideSession,
        vehicleSession: RideDynamicsTestVehicleSession
    ) -> RideDynamicsCardViewModel {
        RideDynamicsCardViewModel(
            rideSession: rideSession,
            vehicleSession: vehicleSession,
            mapper: RideDashboardMapperFactory.makeRideDynamicsMapper(
                locale: .init(identifier: "en_GB")
            )
        )
    }

    private struct Fixture {
        let viewModel: RideDynamicsCardViewModel
        let vehicleSession: RideDynamicsTestVehicleSession
        let rideSession: RideDynamicsTestRideSession
    }
}
