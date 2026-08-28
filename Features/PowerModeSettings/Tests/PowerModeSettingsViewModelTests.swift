import BikeDomain
@testable import PowerModeSettings
import SettingsDomain
import Testing
import TestSupport
import VehicleSession

@MainActor
@Suite("Power mode settings view model")
struct PowerModeSettingsViewModelTests {
    private let vin = "FENRTEST000000001"

    @Test("Saves unique names and rejects duplicates without letter case")
    func savesAndRejectsDuplicates() async {
        let fixture = makeFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.canEditName })

        fixture.viewModel.saveName("Eco")
        #expect(await waitUntil {
            await fixture.repository.settings.powerModeName(forVIN: vin, mapIndex: 0)?.value == "Eco"
        })

        fixture.viewModel.selectMap(index: 1)
        fixture.viewModel.saveName("ECO")

        #expect(fixture.viewModel.viewState.nameError == "Use a unique name for each map.")
        #expect(await fixture.repository.settings.powerModeName(forVIN: vin, mapIndex: 1) == nil)
        fixture.viewModel.stop()
    }

    @Test("Resets a saved name to the numeric fallback")
    func resetsName() async throws {
        let fixture = makeFixture()
        var settings = AppSettings()
        try settings.setPowerModeName(try PowerModeName("MX"), forVIN: vin, mapIndex: 0)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.currentName == "MX" })

        fixture.viewModel.resetName()

        #expect(await waitUntil {
            await fixture.repository.settings.powerModeName(forVIN: vin, mapIndex: 0) == nil
        })
        #expect(fixture.viewModel.viewState.maps.first?.title == "1")
        fixture.viewModel.stop()
    }

    @Test("Enables guarded map controls and preserves sibling values")
    func preparesAndWritesAdjustments() async {
        let settingsRepository = PowerModeSettingsRepository()
        let bikeRepository = PowerModeSettingsBikeRepository()
        let vehicleSession = PowerModeSettingsVehicleSession()
        let viewModel = PowerModeSettingsViewModel(
            vehicleSession: vehicleSession,
            useCases: .init(
                saveSettings: .init(repository: settingsRepository),
                preparePowerModeControl: .init(repository: bikeRepository),
                setPowerModeConfiguration: .init(repository: bikeRepository),
                prepareTractionControl: .init(repository: bikeRepository),
                setTractionControlConfiguration: .init(repository: bikeRepository)
            ),
            mapper: .init()
        )
        viewModel.start()
        await vehicleSession.send(.init(
            telemetry: .init(
                mode: .index(1),
                powerModeConfigurations: [
                    0: .init(
                        mapIndex: 0,
                        horsepower: 35,
                        regenerativeBrakingPercent: 40,
                        powerTractionPercent: 20,
                        brakingTractionPercent: 15
                    )
                ]
            ),
            connection: .init(state: .receivingTelemetry(peripheralName: "FENR Debug")),
            settings: .init(),
            profile: .init(vin: vin),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))

        #expect(await waitUntil {
            let adjustments = viewModel.viewState.adjustments
            return adjustments.count == 4 && adjustments.allSatisfy(\.isEnabled)
        })
        viewModel.updateAdjustment(id: "power", value: 50)

        #expect(await waitUntil {
            await bikeRepository.writes == [
                .init(mapIndex: 0, horsepower: 50, regenerativeBrakingPercent: 40)
            ]
        })
        #expect(viewModel.viewState.statusText == "Map 1 confirmed by the bike")
        #expect(viewModel.viewState.adjustments[0].value == 50)
        #expect(viewModel.viewState.adjustments[1].value == 40)

        viewModel.updateAdjustment(id: "brakingTraction", value: 30)

        #expect(await waitUntil {
            await bikeRepository.tractionWrites == [
                .init(mapIndex: 0, powerTractionPercent: 20, brakingTractionPercent: 30)
            ]
        })
        #expect(viewModel.viewState.adjustments[2].value == 20)
        #expect(viewModel.viewState.adjustments[3].value == 30)
        viewModel.stop()
    }

    private func makeFixture() -> Fixture {
        let repository = PowerModeSettingsRepository()
        let vehicleSession = PowerModeSettingsVehicleSession()
        return Fixture(
            viewModel: PowerModeSettingsViewModel(
                vehicleSession: vehicleSession,
                useCases: .init(saveSettings: .init(repository: repository)),
                mapper: .init()
            ),
            vehicleSession: vehicleSession,
            repository: repository
        )
    }

    private func snapshot(settings: AppSettings = .init()) -> VehicleSessionSnapshot {
        .init(
            settings: settings,
            profile: .init(vin: vin),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        )
    }

    private struct Fixture {
        let viewModel: PowerModeSettingsViewModel
        let vehicleSession: PowerModeSettingsVehicleSession
        let repository: PowerModeSettingsRepository
    }
}
