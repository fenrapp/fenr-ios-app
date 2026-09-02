import BikeDomain
import Foundation
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
        let fixture = makeFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())

        #expect(await waitUntil {
            let adjustments = fixture.viewModel.viewState.adjustments
            return adjustments.count == 4 && adjustments.allSatisfy(\.isEnabled)
        })
        fixture.viewModel.updateAdjustment(id: .power, value: 50)

        #expect(await waitUntil {
            await fixture.bikeRepository.writes == [
                .init(mapIndex: 0, horsepower: 50, regenerativeBrakingPercent: 40)
            ]
        })
        #expect(fixture.viewModel.viewState.statusText == "Map 1 confirmed by the bike")
        #expect(fixture.viewModel.viewState.adjustments[0].value == 50)
        #expect(fixture.viewModel.viewState.adjustments[1].value == 40)

        fixture.viewModel.updateAdjustment(id: .brakingTraction, value: 30)

        #expect(await waitUntil {
            await fixture.bikeRepository.tractionWrites == [
                .init(mapIndex: 0, powerTractionPercent: 20, brakingTractionPercent: 30)
            ]
        })
        #expect(fixture.viewModel.viewState.adjustments[2].value == 20)
        #expect(fixture.viewModel.viewState.adjustments[3].value == 30)
        fixture.viewModel.stop()
    }
}

extension PowerModeSettingsViewModelTests {
    @Test("Refreshes once per connection session and again after reconnect")
    func refreshesOncePerSessionAndAgainAfterReconnect() async {
        let fixture = makeFixture()
        fixture.viewModel.start()

        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { await fixture.bikeRepository.refreshCount == 1 })

        await fixture.vehicleSession.send(connectedSnapshot())
        await fixture.vehicleSession.send(.init(
            connection: .init(state: .reconnecting(
                vin: vin,
                attempt: 1,
                maximumAttempts: 3
            ))
        ))
        #expect(await waitUntil {
            fixture.viewModel.viewState.connectionText == "Connecting to bike"
        })
        #expect(await fixture.bikeRepository.refreshCount == 1)

        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { await fixture.bikeRepository.refreshCount == 2 })
        fixture.viewModel.stop()
    }

    @Test("Stop cancels refresh and restart requests it again")
    func stopCancelsRefreshAndRestartRequestsItAgain() async {
        let refreshOperation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(refreshOperation: refreshOperation)
        let fixture = makeFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { await refreshOperation.pendingCount == 1 })

        fixture.viewModel.stop()
        #expect(!fixture.viewModel.viewState.canRefresh)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { await refreshOperation.requestCount == 2 })

        await refreshOperation.succeedAll()
        #expect(await waitUntil { !fixture.viewModel.viewState.statusIsError })
        fixture.viewModel.stop()
    }

    @Test("Blocks refresh while a control operation is in flight")
    func blocksRefreshWhileControlOperationIsInFlight() async {
        let writeOperation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(baseWriteOperation: writeOperation)
        let fixture = makeFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })

        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        let refreshCount = await bikeRepository.refreshCount
        fixture.viewModel.refresh()
        #expect(await bikeRepository.refreshCount == refreshCount)

        await writeOperation.succeedNext()
        #expect(await waitUntil { await bikeRepository.writes.count == 1 })
        fixture.viewModel.stop()
    }
}

extension PowerModeSettingsViewModelTests {
    @Test("Does not write before preparation completes")
    func doesNotWriteBeforePreparationCompletes() async {
        let preparation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(basePreparationOperation: preparation)
        let fixture = makeFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { await preparation.pendingCount == 1 })

        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await bikeRepository.requestedWrites.isEmpty)

        await preparation.succeedNext()
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await waitUntil { await bikeRepository.writes.count == 1 })
        fixture.viewModel.stop()
    }

    @Test("Serializes base writes and preserves confirmed sibling values")
    func serializesBaseWritesAndPreservesConfirmedSiblingValues() async {
        let writeOperation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(baseWriteOperation: writeOperation)
        let fixture = makeFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })

        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        fixture.viewModel.updateAdjustment(id: .regeneration, value: -30)
        #expect(await bikeRepository.requestedWrites.count == 1)
        await writeOperation.succeedNext()
        #expect(await waitUntil { await bikeRepository.writes.count == 1 })

        fixture.viewModel.updateAdjustment(id: .regeneration, value: -30)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        await writeOperation.succeedNext()
        #expect(await waitUntil {
            await bikeRepository.writes == [
                .init(mapIndex: 0, horsepower: 50, regenerativeBrakingPercent: 40),
                .init(mapIndex: 0, horsepower: 50, regenerativeBrakingPercent: -30)
            ]
        })
        fixture.viewModel.stop()
    }

    @Test("Selecting another map cancels stale preparation and write presentation")
    func selectingAnotherMapCancelsStalePreparationAndWritePresentation() async {
        let preparation = ControllablePowerModeSettingsOperation()
        let writeOperation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(
            basePreparationOperation: preparation,
            baseWriteOperation: writeOperation
        )
        let fixture = makeFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot(mapCount: 3))
        #expect(await waitUntil { await preparation.pendingCount == 1 })

        fixture.viewModel.selectMap(index: 1)
        #expect(await waitUntil { await preparation.requestCount == 2 })
        await preparation.succeedNext()
        #expect(fixture.viewModel.viewState.selectedMapIndex == 1)
        let hasEnabledAdjustment = fixture.viewModel.viewState.adjustments.contains { $0.isEnabled }
        #expect(!hasEnabledAdjustment)
        await preparation.succeedNext()
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })

        fixture.viewModel.updateAdjustment(id: .power, value: 55)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        fixture.viewModel.selectMap(index: 2)
        #expect(await waitUntil { await preparation.requestCount == 3 })
        await writeOperation.succeedNext()
        #expect(fixture.viewModel.viewState.selectedMapIndex == 2)
        #expect(fixture.viewModel.viewState.statusText != "Map 2 confirmed by the bike")
        await preparation.succeedNext()
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        fixture.viewModel.stop()
    }

    @Test("Disconnect cancels preparation and disables controls")
    func disconnectCancelsPreparationAndDisablesControls() async {
        let preparation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(basePreparationOperation: preparation)
        let fixture = makeFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { await preparation.pendingCount == 1 })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .disconnected(reason: "Connection lost"))
        ))
        #expect(await waitUntil {
            fixture.viewModel.viewState.connectionText == "Bike disconnected"
        })
        await preparation.succeedNext()
        let hasEnabledAdjustment = fixture.viewModel.viewState.adjustments.contains { $0.isEnabled }
        #expect(!hasEnabledAdjustment)
        fixture.viewModel.stop()
    }

    @Test("Write failure keeps confirmed values and requires fresh verification")
    func writeFailureDoesNotPublishUnconfirmedValuesAndRequiresFreshVerification() async {
        let writeOperation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(baseWriteOperation: writeOperation)
        let fixture = makeFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })

        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        await writeOperation.failNext(message: "write failed")
        #expect(await waitUntil { fixture.viewModel.viewState.statusIsError })
        #expect(fixture.viewModel.viewState.statusText == "Unable to apply the map. Try again.")
        #expect(!fixture.viewModel.viewState.statusText.contains("write failed"))
        #expect(fixture.viewModel.viewState.adjustments[0].value == 35)
        #expect(!fixture.viewModel.viewState.adjustments[0].isEnabled)

        fixture.viewModel.refresh()
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        fixture.viewModel.stop()
    }

    @Test("Stop allows pending settings saves to finish in order")
    func stopAllowsPendingSettingsSaveToFinishInOrder() async {
        let fixture = makeFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.canEditName })

        fixture.viewModel.saveName("Eco")
        fixture.viewModel.saveName("Enduro")
        fixture.viewModel.stop()

        #expect(await waitUntil {
            await fixture.repository.settings.powerModeName(forVIN: vin, mapIndex: 0)?.value == "Enduro"
        })
    }
}

extension PowerModeSettingsViewModelTests {
    @Test("Does not send traction values outside the supported range")
    func doesNotSendTractionValuesOutsideSupportedRange() async {
        let bikeRepository = PowerModeSettingsBikeRepository()
        let fixture = makeFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })

        for invalidValue in [-1, 101, .nan, 12.5] as [Double] {
            fixture.viewModel.updateAdjustment(id: .powerTraction, value: invalidValue)
        }
        #expect(await bikeRepository.requestedTractionWrites.isEmpty)

        await fixture.vehicleSession.send(connectedSnapshot(brakingTractionPercent: .nan))
        #expect(await waitUntil {
            fixture.viewModel.viewState.adjustments.suffix(2).allSatisfy { !$0.isEnabled }
        })
        fixture.viewModel.updateAdjustment(id: .powerTraction, value: 50)
        #expect(await bikeRepository.requestedTractionWrites.isEmpty)

        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        fixture.viewModel.updateAdjustment(id: .powerTraction, value: 0)
        #expect(await waitUntil { await bikeRepository.tractionWrites.count == 1 })
        fixture.viewModel.updateAdjustment(id: .brakingTraction, value: 100)

        #expect(await waitUntil {
            await bikeRepository.tractionWrites == [
                .init(mapIndex: 0, powerTractionPercent: 0, brakingTractionPercent: 15),
                .init(mapIndex: 0, powerTractionPercent: 0, brakingTractionPercent: 100)
            ]
        })
        fixture.viewModel.stop()
    }
    private func makeFixture(bikeRepository: PowerModeSettingsBikeRepository = .init()) -> Fixture {
        let repository = PowerModeSettingsRepository()
        let vehicleSession = PowerModeSettingsVehicleSession()
        return Fixture(
            viewModel: PowerModeSettingsViewModel(
                vehicleSession: vehicleSession,
                useCases: .init(
                    saveSettings: .init(repository: repository),
                    refreshPowerModes: .init(repository: bikeRepository),
                    preparePowerModeControl: .init(repository: bikeRepository),
                    setPowerModeConfiguration: .init(repository: bikeRepository),
                    prepareTractionControl: .init(repository: bikeRepository),
                    setTractionControlConfiguration: .init(repository: bikeRepository)
                ),
                mapper: .init(locale: Locale(identifier: "en_US"))
            ),
            vehicleSession: vehicleSession,
            repository: repository,
            bikeRepository: bikeRepository
        )
    }
    private func snapshot(settings: AppSettings = .init()) -> VehicleSessionSnapshot {
        .init(
            settings: settings,
            profile: .init(vin: vin),
            hasReceivedSettings: true,
            hasReceivedProfile: true,
            isCanonicalTelemetryAvailable: true
        )
    }

    private func connectedSnapshot(
        mapCount: Int = 1, brakingTractionPercent: Double = 15
    ) -> VehicleSessionSnapshot {
        let configurations = Dictionary(uniqueKeysWithValues: (0 ..< mapCount).map { mapIndex in
            (
                mapIndex,
                BikePowerModeConfiguration(
                    mapIndex: mapIndex,
                    horsepower: 35 + mapIndex,
                    regenerativeBrakingPercent: 40,
                    powerTractionPercent: 20,
                    brakingTractionPercent: brakingTractionPercent
                )
            )
        })
        return .init(
            telemetry: .init(
                mode: .index(1),
                powerModeConfigurations: configurations
            ),
            connection: .init(state: .receivingTelemetry(peripheralName: "FENR Debug")),
            settings: .init(),
            profile: .init(vin: vin),
            hasReceivedSettings: true,
            hasReceivedProfile: true,
            isCanonicalTelemetryAvailable: true
        )
    }

    private func controlsAreEnabled(_ viewModel: PowerModeSettingsViewModel) -> Bool {
        let adjustments = viewModel.viewState.adjustments
        return adjustments.count == 4 && adjustments.allSatisfy(\.isEnabled)
    }
    private struct Fixture {
        let viewModel: PowerModeSettingsViewModel
        let vehicleSession: PowerModeSettingsVehicleSession
        let repository: PowerModeSettingsRepository
        let bikeRepository: PowerModeSettingsBikeRepository
    }
}
