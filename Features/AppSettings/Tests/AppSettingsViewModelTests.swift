import AppSettings
import BikeDomain
import EnvironmentDomain
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("App settings view model")
struct AppSettingsViewModelTests {
    @Test("Saves selected settings")
    func savesSelectedSettings() async {
        let fixture = AppSettingsViewModelFixture(
            profile: .init(vin: AppSettingsViewModelFixture.vin, declaredPowerTier: .alpha)
        )
        let viewModel = fixture.viewModel

        await fixture.start()
        #expect(await waitUntil { viewModel.viewState.powerTier.status == "Pending bike verification" })
        viewModel.selectSpeedSource(id: SpeedSource.hybrid.rawValue)
        viewModel.selectDashboardProgressBarMode(id: DashboardProgressBarMode.hidden.rawValue)
        viewModel.selectDashboardBatteryIndicatorMode(id: DashboardBatteryIndicatorMode.estimatedRange.rawValue)
        viewModel.selectDashboardDeviceBatteryDisplayMode(id: DashboardDeviceBatteryDisplayMode.iconOnly.rawValue)
        viewModel.setShowsDashboardTemperatures(true)
        viewModel.selectMeasurementSystem(id: MeasurementSystem.imperial.rawValue)
        viewModel.selectBatteryPackCapacity(id: BatteryPackCapacity.sixPointEightKilowattHours.rawValue)
        var expectedSettings = AppSettings(
            speedSource: .hybrid,
            dashboardProgressBarMode: .hidden,
            dashboardBatteryIndicatorMode: .estimatedRange,
            dashboardDeviceBatteryDisplayMode: .iconOnly,
            showsDashboardTemperatures: true,
            measurementSystem: .imperial
        )
        expectedSettings.setBatteryPackCapacity(
            .sixPointEightKilowattHours,
            forVIN: AppSettingsViewModelFixture.vin
        )
        let didSave = await waitUntil {
            await fixture.settingsRepository.settings == expectedSettings
        }

        #expect(didSave)
        viewModel.stop()
    }

    @Test("Publishes controls shaped for direct rendering")
    func publishesPresentationControls() async {
        let fixture = AppSettingsViewModelFixture()
        let viewModel = fixture.viewModel

        await fixture.start()
        viewModel.selectSpeedSource(id: SpeedSource.gps.rawValue)
        #expect(await waitUntil {
            viewModel.viewState.speedSource.locationPermission == .authorized
        })

        #expect(viewModel.viewState.speedSource.selection.selectedID == SpeedSource.gps.rawValue)
        #expect(viewModel.viewState.speedSource.selection.options.map(\.title) == ["Bike", "GPS", "GPS+"])
        #expect(viewModel.viewState.speedSource.description.contains("phone GPS"))
        #expect(viewModel.viewState.speedSource.locationPermission == .authorized)
        #expect(viewModel.viewState.dashboardProgressBarMode.selection.selectedID == "energy")
        #expect(
            viewModel.viewState.dashboardProgressBarMode.selection.options.map(\.title)
                == ["Energy", "Speed", "Hidden"]
        )
        #expect(viewModel.viewState.dashboardProgressBarMode.description.contains("Regeneration"))
        #expect(viewModel.viewState.dashboardBatteryIndicatorMode.selectedID == "percentage")
        #expect(
            viewModel.viewState.dashboardBatteryIndicatorMode.options.map(\.title)
                == ["Percentage", "Estimated range"]
        )
        #expect(viewModel.viewState.dashboardDeviceBatteryDisplayMode.selectedID == "iconAndText")
        #expect(
            viewModel.viewState.dashboardDeviceBatteryDisplayMode.options.map(\.title)
                == ["Icon and percentage", "Percentage only", "Icon only", "Hidden"]
        )
        #expect(!viewModel.viewState.showsDashboardTemperatures)
        #expect(viewModel.viewState.measurementSystem.options.map(\.title) == ["System", "Metric", "Imperial"])
        #expect(viewModel.viewState.batteryCapacity.options.map(\.title) == ["6.8 kWh", "7.2 kWh"])

        viewModel.selectSpeedSource(id: SpeedSource.motorcycle.rawValue)
        #expect(viewModel.viewState.speedSource.locationPermission == nil)
        viewModel.stop()
    }

    @Test("Serializes declared power tier saves")
    func serializesDeclaredPowerTierSaves() async {
        let fixture = AppSettingsViewModelFixture(
            profile: .init(vin: AppSettingsViewModelFixture.vin, declaredPowerTier: .alpha)
        )
        await fixture.profileRepository.setShouldBlockSaves(true)
        var saveStarts = await fixture.profileRepository.observeSaveStarts().makeAsyncIterator()

        await fixture.start()
        #expect(await waitUntil {
            fixture.viewModel.viewState.powerTier.status == "Pending bike verification"
        })
        fixture.viewModel.selectDeclaredPowerTier(id: BikeDeclaredPowerTier.standard.rawValue)
        let firstSave = await saveStarts.next()

        fixture.viewModel.selectDeclaredPowerTier(id: BikeDeclaredPowerTier.alpha.rawValue)
        #expect(await fixture.profileRepository.savedProfiles.count == 1)

        await fixture.profileRepository.releaseNextSave()
        let secondSave = await saveStarts.next()
        await fixture.profileRepository.releaseNextSave()

        #expect(firstSave?.declaredPowerTier == .standard)
        #expect(secondSave?.declaredPowerTier == .alpha)
        #expect(await fixture.profileRepository.savedProfiles.map(\.declaredPowerTier) == [.standard, .alpha])
    }

    @Test("Publishes power tier verification success")
    func publishesPowerTierVerificationSuccess() async {
        let fixture = AppSettingsViewModelFixture()
        var refreshStarts = await fixture.bikeRepository.observeRefreshStarts().makeAsyncIterator()

        await fixture.start()
        fixture.viewModel.verifyPowerTierWithBike()
        _ = await refreshStarts.next()

        #expect(await waitUntil {
            fixture.viewModel.viewState.powerTier.verificationMessage == "Bike verification completed"
        })
        #expect(fixture.viewModel.viewState.powerTier.status == "Standard baseline · 60 HP max")
        #expect(!fixture.viewModel.viewState.powerTier.isVerifying)
        #expect(!fixture.viewModel.viewState.powerTier.verificationMessageIsError)
        fixture.viewModel.stop()
    }

    @Test("Publishes power tier verification failure")
    func publishesPowerTierVerificationFailure() async {
        let fixture = AppSettingsViewModelFixture(refreshBehavior: .failure)
        var refreshStarts = await fixture.bikeRepository.observeRefreshStarts().makeAsyncIterator()

        await fixture.start()
        fixture.viewModel.verifyPowerTierWithBike()
        _ = await refreshStarts.next()

        #expect(await waitUntil {
            fixture.viewModel.viewState.powerTier.verificationMessage == "Verification failed: Refresh failed"
        })
        #expect(fixture.viewModel.viewState.powerTier.status == "Standard baseline · 60 HP max")
        #expect(!fixture.viewModel.viewState.powerTier.isVerifying)
        #expect(fixture.viewModel.viewState.powerTier.verificationMessageIsError)
        fixture.viewModel.stop()
    }

    @Test("Stop cancels power tier verification")
    func stopCancelsPowerTierVerification() async {
        let fixture = AppSettingsViewModelFixture(refreshBehavior: .suspended)
        var refreshStarts = await fixture.bikeRepository.observeRefreshStarts().makeAsyncIterator()
        var refreshCancellations = await fixture.bikeRepository.observeRefreshCancellations().makeAsyncIterator()

        await fixture.start()
        fixture.viewModel.verifyPowerTierWithBike()
        _ = await refreshStarts.next()
        #expect(fixture.viewModel.viewState.powerTier.isVerifying)

        fixture.viewModel.stop()
        _ = await refreshCancellations.next()

        #expect(!fixture.viewModel.viewState.powerTier.isVerifying)
        #expect(fixture.viewModel.viewState.powerTier.verificationMessage == nil)
    }

    @Test("Keeps observing while a settings detail remains presented")
    func keepsObservingAcrossSettingsNavigation() async {
        let fixture = AppSettingsViewModelFixture()

        await fixture.start()
        fixture.viewModel.start()
        fixture.viewModel.stop()

        await fixture.settingsRepository.save(.init(measurementSystem: .imperial))

        #expect(await waitUntil {
            fixture.viewModel.viewState.measurementSystem.selectedID == MeasurementSystem.imperial.rawValue
        })
        fixture.viewModel.stop()
    }

}
