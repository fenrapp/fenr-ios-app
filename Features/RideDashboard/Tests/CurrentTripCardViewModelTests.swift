import BikeDomain
import EnvironmentDomain
import Foundation
import RideDashboard
import RideSessionDomain
import SettingsDomain
import Testing
import TestSupport

@Suite("Current trip card view model")
@MainActor
struct CurrentTripCardViewModelTests {
    @Test("Tracks while hidden and publishes when the card becomes visible")
    func tracksWhileHidden() async {
        let fixture = makeFixture()
        fixture.viewModel.start()
        await fixture.bikeRepository.sendConnection(
            BikeConnection(state: .receivingTelemetry(peripheralName: "SYNTHETIC"))
        )
        await fixture.bikeRepository.sendTelemetry(driveTelemetry())

        #expect(!fixture.viewModel.viewState.isActive)
        #expect(await waitUntil {
            await fixture.tripRepository.currentActiveTrip() != nil
        })

        fixture.viewModel.setIsVisible(true)

        #expect(fixture.viewModel.viewState.isActive)
        #expect(fixture.viewModel.viewState.maximumSpeed.valueText == "42")
    }

    @Test("Reset archives the current trip and starts a replacement while still in gear")
    func resetsActiveTrip() async {
        let fixture = makeFixture()
        fixture.viewModel.setIsVisible(true)
        fixture.viewModel.start()
        await fixture.bikeRepository.sendConnection(
            BikeConnection(state: .receivingTelemetry(peripheralName: "SYNTHETIC"))
        )
        await fixture.bikeRepository.sendTelemetry(driveTelemetry())
        #expect(await waitUntil {
            await fixture.tripRepository.currentActiveTrip() != nil
        })
        let originalID = await fixture.tripRepository.currentActiveTrip()?.id

        fixture.viewModel.resetCurrentTrip()

        #expect(await waitUntil {
            let completionCount = await fixture.tripRepository.completionCount()
            let activeTrip = await fixture.tripRepository.currentActiveTrip()
            return completionCount == 1 && activeTrip?.id != originalID
        })
        #expect(fixture.viewModel.viewState.isActive)
        #expect(fixture.viewModel.viewState.distance.valueText == "0")
        #expect(await waitUntil { fixture.historyChangeRecorder.count == 1 })
    }

    @Test("Pause and resume persist the current trip state")
    func pausesAndResumesTrip() async {
        let fixture = makeFixture()
        fixture.viewModel.setIsVisible(true)
        fixture.viewModel.start()
        await fixture.bikeRepository.sendConnection(
            BikeConnection(state: .receivingTelemetry(peripheralName: "SYNTHETIC"))
        )
        await fixture.bikeRepository.sendTelemetry(driveTelemetry())
        #expect(await waitUntil {
            await fixture.tripRepository.currentActiveTrip() != nil
        })

        fixture.viewModel.togglePauseCurrentTrip()

        #expect(fixture.viewModel.viewState.isPaused)
        #expect(await waitUntil {
            await fixture.tripRepository.currentActiveTrip()?.isPaused == true
        })

        fixture.viewModel.togglePauseCurrentTrip()

        #expect(!fixture.viewModel.viewState.isPaused)
        #expect(await waitUntil {
            await fixture.tripRepository.currentActiveTrip()?.isPaused == false
        })
    }

    @Test("Uses the GPS speed selected in settings for trip speed metrics")
    func usesSelectedGPSSpeed() async {
        let fixture = makeFixture(speedSource: .gps)
        fixture.viewModel.setIsVisible(true)
        fixture.viewModel.start()
        await fixture.deviceSpeedRepository.send(
            DeviceSpeedSample(
                kilometersPerHour: 67,
                accuracyMetersPerSecond: 2,
                observedAt: fixture.date
            )
        )
        await fixture.bikeRepository.sendConnection(
            BikeConnection(state: .receivingTelemetry(peripheralName: "SYNTHETIC"))
        )
        await fixture.bikeRepository.sendTelemetry(driveTelemetry())

        #expect(await waitUntil {
            await fixture.tripRepository.currentActiveTrip()?.maximumSpeedKilometersPerHour == 67
        })
        #expect(fixture.viewModel.viewState.maximumSpeed.valueText == "67")
        #expect(fixture.viewModel.viewState.speedSourceIndicator?.text == "GPS")
    }

    private func makeFixture(speedSource: SpeedSource = .motorcycle) -> Fixture {
        let bikeRepository = CurrentTripCardBikeRepository()
        let tripRepository = CurrentTripCardTripRepository()
        let settingsRepository = CurrentTripCardSettingsRepository(speedSource: speedSource)
        let deviceSpeedRepository = CurrentTripCardDeviceSpeedRepository()
        let historyChangeRecorder = CurrentTripHistoryChangeRecorder()
        let fixedDate = Date(timeIntervalSince1970: 1_000)
        let viewModel = CurrentTripCardViewModel(
            useCases: .init(
                observeTelemetry: .init(repository: bikeRepository),
                observeConnection: .init(repository: bikeRepository),
                observeSettings: .init(repository: settingsRepository),
                observeDeviceSpeed: .init(repository: deviceSpeedRepository),
                prepareRideTripSession: .init(repository: tripRepository),
                saveActiveRideTrip: .init(repository: tripRepository),
                completeRideTrip: .init(repository: tripRepository)
            ),
            mapper: RideDashboardMapperFactory.makeCurrentTripMapper(
                locale: Locale(identifier: "en_GB")
            ),
            deviceSpeedResolver: DeviceSpeedResolver(
                now: { fixedDate },
                maximumAccuracyMetersPerSecond: 5,
                maximumSampleAge: 5
            ),
            applicationSessionID: UUID(),
            now: { fixedDate },
            onHistoryChanged: historyChangeRecorder.record
        )
        return Fixture(
            viewModel: viewModel,
            bikeRepository: bikeRepository,
            tripRepository: tripRepository,
            deviceSpeedRepository: deviceSpeedRepository,
            historyChangeRecorder: historyChangeRecorder,
            date: fixedDate
        )
    }

    private func driveTelemetry() -> BikeTelemetry {
        BikeTelemetry(
            speed: .known(kmh: 42, kmhX10: 420),
            odometer: .known(kilometers: 100, centiKilometers: 10_000),
            statusFlags: .init(isOn: true, isInGear: true)
        )
    }

    private struct Fixture {
        let viewModel: CurrentTripCardViewModel
        let bikeRepository: CurrentTripCardBikeRepository
        let tripRepository: CurrentTripCardTripRepository
        let deviceSpeedRepository: CurrentTripCardDeviceSpeedRepository
        let historyChangeRecorder: CurrentTripHistoryChangeRecorder
        let date: Date
    }
}
