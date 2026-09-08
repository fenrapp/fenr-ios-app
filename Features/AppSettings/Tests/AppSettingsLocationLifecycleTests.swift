@testable import AppSettings
import EnvironmentDomain
import Testing
import TestSupport

@MainActor
@Suite("App settings location lifecycle")
struct AppSettingsLocationLifecycleTests {
    @Test("A canceled permission read cannot change the next settings render")
    func canceledPermissionReadDoesNotMutateState() async {
        let settingsRepository = SettingsRepository()
        let locationRepository = ControllableLocationRepository()
        let viewModel = AppSettingsViewModel(
            useCases: .init(
                settings: .init(
                    update: .init(repository: settingsRepository),
                    observe: .init(repository: settingsRepository)
                ),
                location: .init(
                    authorizationStatus: .init(repository: locationRepository),
                    requestAuthorization: .init(repository: locationRepository)
                )
            ),
            mapper: AppSettingsViewStateMapper()
        )
        viewModel.start()
        #expect(await waitUntil { viewModel.pendingSettings.confirmed != nil })
        #expect(await waitUntil { locationRepository.hasPendingRead })

        let teardown = Task { await viewModel.stopAndWait() }
        #expect(await waitUntil { locationRepository.wasCancelled })
        locationRepository.completeRead(with: .denied)
        await teardown.value

        viewModel.selectSpeedSource(id: "gps")
        #expect(viewModel.viewState.speedSource.locationPermission == .notDetermined)
        await viewModel.stopAndWait()
    }
}
