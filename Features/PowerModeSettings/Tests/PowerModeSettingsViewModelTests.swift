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

    @Test("Keeps pending values visible and retains failed traction proposals", arguments: [
        PowerModeAdjustmentID.power, .regeneration, .powerTraction, .brakingTraction
    ])
    func pendingValuesRemainVisible(id: PowerModeAdjustmentID) async {
        let operation = ControllablePowerModeSettingsOperation()
        let fixture = makePowerModeSettingsFixture(bikeRepository: .init(
            baseWriteOperation: operation, tractionWriteOperation: operation
        ))
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        let original = fixture.viewModel.viewState.adjustments
        fixture.viewModel.updateAdjustment(id: id, value: 50)
        #expect(fixture.viewModel.viewState.adjustments.first { $0.id == id }?.value == 50)
        #expect(fixture.viewModel.viewState.adjustments.allSatisfy { !$0.isEnabled })
        #expect(await waitUntil { await operation.pendingCount == 1 })
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(fixture.viewModel.viewState.adjustments.first { $0.id == id }?.value == 50)
        for sibling in original where sibling.id != id {
            #expect(fixture.viewModel.viewState.adjustments.first { $0.id == sibling.id }?.value == sibling.value)
        }
        await operation.failNext(message: "Rejected")
        #expect(await waitUntil { feedback(for: id, in: fixture.viewModel).state == .failed })
        let expectedAfterFailure = id == .powerTraction || id == .brakingTraction
            ? 50 : original.first { $0.id == id }?.value
        #expect(fixture.viewModel.viewState.adjustments.first { $0.id == id }?.value == expectedAfterFailure)
        fixture.viewModel.refresh()
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        fixture.viewModel.updateAdjustment(id: id, value: 50)
        #expect(await waitUntil { await operation.pendingCount == 1 })
        await operation.succeedNext()
        #expect(await waitUntil { feedback(for: id, in: fixture.viewModel).state == .confirmed })
        #expect(fixture.viewModel.viewState.adjustments.first { $0.id == id }?.value == 50)
        #expect(controlsAreEnabled(fixture.viewModel))
        fixture.viewModel.stop()
    }

    @Test("Stopping clears optimistic values and ignores a late write completion", arguments: [
        PowerModeAdjustmentID.power, .regeneration, .powerTraction, .brakingTraction
    ])
    func stoppingClearsPendingValue(id: PowerModeAdjustmentID) async {
        let operation = ControllablePowerModeSettingsOperation()
        let fixture = makePowerModeSettingsFixture(bikeRepository: .init(
            baseWriteOperation: operation, tractionWriteOperation: operation
        ))
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        let confirmed = fixture.viewModel.viewState.adjustments.first { $0.id == id }?.value
        fixture.viewModel.updateAdjustment(id: id, value: 50)
        #expect(await waitUntil { await operation.pendingCount == 1 })
        let stopping = Task { await fixture.viewModel.stopAndWait() }
        #expect(await waitUntil { feedback(for: id, in: fixture.viewModel).state == .idle })
        #expect(fixture.viewModel.viewState.adjustments.first { $0.id == id }?.value == confirmed)
        await operation.succeedNext()
        await stopping.value
        #expect(fixture.viewModel.viewState.adjustments.first { $0.id == id }?.value == confirmed)
        #expect(fixture.viewModel.viewState.adjustments.allSatisfy { !$0.isEnabled })
    }

    @Test("Saves unique names and rejects duplicates without letter case")
    func savesAndRejectsDuplicates() async {
        let fixture = makePowerModeSettingsFixture()
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

    @Test("Rejects a name when a bike profile is unavailable")
    func rejectsNameWithoutProfile() async {
        let fixture = makePowerModeSettingsFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(.init(hasReceivedSettings: true))
        #expect(await waitUntil {
            fixture.viewModel.viewState.connectionText == "Bike unavailable"
        })

        fixture.viewModel.saveName("Eco")
        #expect(fixture.viewModel.viewState.nameError == "A bike profile is required to save map names.")
        fixture.viewModel.stop()
    }

    @Test("Resets a saved name to the numeric fallback")
    func resetsName() async throws {
        let fixture = makePowerModeSettingsFixture()
        var settings = AppSettings()
        try settings.setPowerModeName(try PowerModeName("MX"), forVIN: vin, mapIndex: 0)
        await fixture.repository.send(settings)
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
        let fixture = makePowerModeSettingsFixture()
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

    @Test("Publishes applying and confirmed feedback only after write confirmation")
    func publishesApplyingAndConfirmedFeedback() async {
        let writeOperation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(baseWriteOperation: writeOperation)
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })

        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        #expect(feedback(for: .power, in: fixture.viewModel).state == .applying)
        #expect(feedback(for: .power, in: fixture.viewModel).isActivity)
        #expect(fixture.viewModel.viewState.adjustments.allSatisfy { adjustment in
            adjustment.id == .power || adjustment.feedback.state == .idle
        })

        await writeOperation.succeedNext()
        #expect(await waitUntil {
            feedback(for: .power, in: fixture.viewModel).state == .confirmed
        })
        #expect(fixture.viewModel.viewState.adjustments[0].value == 50)

        fixture.viewModel.updateAdjustment(id: .regeneration, value: 20)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        #expect(feedback(for: .power, in: fixture.viewModel).state == .idle)
        #expect(feedback(for: .regeneration, in: fixture.viewModel).state == .applying)
        await writeOperation.succeedNext()
        #expect(await waitUntil {
            feedback(for: .regeneration, in: fixture.viewModel).state == .confirmed
        })

        fixture.viewModel.stop()
        #expect(feedback(for: .regeneration, in: fixture.viewModel).state == .idle)
    }

    @Test("Pausing presentation does not cancel a committed write")
    func presentationPausePreservesCommittedWrite() async {
        let writeOperation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(baseWriteOperation: writeOperation)
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })

        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        fixture.viewModel.setPresentationActive(false)
        await writeOperation.succeedNext()

        #expect(await waitUntil {
            feedback(for: .power, in: fixture.viewModel).state == .confirmed
        })
        fixture.viewModel.stop()
    }
}

extension PowerModeSettingsViewModelTests {
    @Test("Refreshes once per connection session and again after reconnect")
    func refreshesOncePerSessionAndAgainAfterReconnect() async {
        let fixture = makePowerModeSettingsFixture()
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
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
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
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
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
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
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
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })

        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        fixture.viewModel.updateAdjustment(id: .regeneration, value: 30)
        #expect(await bikeRepository.requestedWrites.count == 1)
        await writeOperation.succeedNext()
        #expect(await waitUntil { await bikeRepository.writes.count == 1 })

        fixture.viewModel.updateAdjustment(id: .regeneration, value: 30)
        #expect(await waitUntil { await writeOperation.pendingCount == 1 })
        await writeOperation.succeedNext()
        #expect(await waitUntil {
            await bikeRepository.writes == [
                .init(mapIndex: 0, horsepower: 50, regenerativeBrakingPercent: 40),
                .init(mapIndex: 0, horsepower: 50, regenerativeBrakingPercent: 30)
            ]
        })
        fixture.viewModel.stop()
    }

    @Test("Map selection cancels stale preparation and waits for an active write")
    func mapSelectionCancelsPreparationAndWaitsForWrite() async {
        let preparation = ControllablePowerModeSettingsOperation()
        let writeOperation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(
            basePreparationOperation: preparation,
            baseWriteOperation: writeOperation
        )
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
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
        #expect(await preparation.requestCount == 2)
        #expect(fixture.viewModel.viewState.selectedMapIndex == 1)
        #expect(feedback(for: .power, in: fixture.viewModel).state == .applying)
        await writeOperation.succeedNext()
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        fixture.viewModel.selectMap(index: 2)
        #expect(await waitUntil { await preparation.requestCount == 3 })
        #expect(feedback(for: .power, in: fixture.viewModel).state == .idle)
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
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
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

    @Test("Disconnect clears confirmed control feedback")
    func disconnectClearsConfirmedControlFeedback() async {
        let fixture = makePowerModeSettingsFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })

        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await waitUntil {
            feedback(for: .power, in: fixture.viewModel).state == .confirmed
        })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .disconnected(reason: "Connection lost"))
        ))
        #expect(await waitUntil {
            feedback(for: .power, in: fixture.viewModel).state == .idle
        })
        fixture.viewModel.stop()
    }

    @Test("Write failure keeps confirmed values and requires fresh verification")
    func writeFailureDoesNotPublishUnconfirmedValuesAndRequiresFreshVerification() async {
        let writeOperation = ControllablePowerModeSettingsOperation()
        let bikeRepository = PowerModeSettingsBikeRepository(baseWriteOperation: writeOperation)
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
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
        #expect(feedback(for: .power, in: fixture.viewModel).state == .failed)
        #expect(feedback(for: .power, in: fixture.viewModel).title == "Unable to apply the map. Try again.")

        fixture.viewModel.refresh()
        #expect(feedback(for: .power, in: fixture.viewModel).state == .idle)
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        fixture.viewModel.stop()
    }

    @Test("Stop cancels queued settings names before persistence begins")
    func stopCancelsQueuedSettingsSaves() async {
        let fixture = makePowerModeSettingsFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.canEditName })

        fixture.viewModel.saveName("Eco")
        fixture.viewModel.saveName("Enduro")
        fixture.viewModel.stop()

        #expect(await fixture.repository.settings.powerModeName(forVIN: vin, mapIndex: 0) == nil)
        #expect(fixture.viewModel.viewState.nameSaveCompletionID == nil)
    }
}

extension PowerModeSettingsViewModelTests {
    @Test("Does not send traction values outside the supported range")
    func doesNotSendTractionValuesOutsideSupportedRange() async {
        let bikeRepository = PowerModeSettingsBikeRepository()
        let fixture = makePowerModeSettingsFixture(bikeRepository: bikeRepository)
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
    @Test("Map name confirmation waits for persistence and failures preserve the saved name")
    func nameConfirmationWaitsForPersistence() async {
        let operation = ControllablePowerModeSettingsOperation()
        let repository = PowerModeSettingsRepository(operation: operation)
        let fixture = makePowerModeSettingsFixture(repository: repository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.canEditName })
        fixture.viewModel.saveName("Eco")
        #expect(await waitUntil { await operation.pendingCount == 1 })
        #expect(fixture.viewModel.viewState.isSavingName)
        #expect(fixture.viewModel.viewState.currentName.isEmpty)
        #expect(fixture.viewModel.viewState.nameSaveCompletionID == nil)
        await operation.failNext(message: "Store unavailable")
        #expect(await waitUntil { fixture.viewModel.viewState.nameError != nil })
        #expect(fixture.viewModel.viewState.nameSaveCompletionID == nil)
        #expect(fixture.viewModel.viewState.currentName.isEmpty)
        fixture.viewModel.saveName("Eco")
        #expect(await waitUntil { await operation.pendingCount == 1 })
        await operation.succeedNext()
        #expect(await waitUntil { fixture.viewModel.viewState.nameSaveCompletionID != nil })
        #expect(fixture.viewModel.viewState.currentName == "Eco")
        fixture.viewModel.stop()
    }

    @Test("A failed name reset keeps the original name and does not confirm dismissal")
    func failedNameResetPreservesName() async throws {
        let operation = ControllablePowerModeSettingsOperation()
        var settings = AppSettings()
        try settings.setPowerModeName(try PowerModeName("Eco"), forVIN: vin, mapIndex: 0)
        let repository = PowerModeSettingsRepository(settings: settings, operation: operation)
        let fixture = makePowerModeSettingsFixture(repository: repository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.currentName == "Eco" })
        fixture.viewModel.resetName()
        #expect(await waitUntil { await operation.pendingCount == 1 })
        await operation.failNext(message: "Store unavailable")
        #expect(await waitUntil { fixture.viewModel.viewState.nameError != nil })
        #expect(fixture.viewModel.viewState.currentName == "Eco")
        #expect(fixture.viewModel.viewState.nameSaveCompletionID == nil)
        fixture.viewModel.stop()
    }

    @Test("Compatible firmware exposes missing traction values without any background write")
    func missingTractionValues() async throws {
        let fixture = makePowerModeSettingsFixture()
        fixture.viewModel.start()
        var incoming = connectedSnapshot()
        var telemetry = incoming.telemetry
        telemetry.powerModeConfigurations[0]?.powerTractionPercent = nil
        telemetry.powerModeConfigurations[0]?.brakingTractionPercent = nil
        incoming = .init(
            telemetry: telemetry, connection: incoming.connection, profile: incoming.profile,
            isCanonicalTelemetryAvailable: true
        )
        await fixture.vehicleSession.send(incoming)
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        #expect(fixture.viewModel.viewState.adjustments[2].value == 0)
        #expect(fixture.viewModel.viewState.adjustments[3].value == 0)
        #expect(fixture.viewModel.viewState.adjustments[2].allowsUnchangedCommit)
        #expect(fixture.viewModel.viewState.controlGroups[1].detail == nil)
        #expect(await fixture.bikeRepository.requestedTractionWrites.isEmpty)
        #expect(await fixture.bikeRepository.preparedTractionMapIndexes.isEmpty)
        fixture.viewModel.updateAdjustment(id: .powerTraction, value: 35)
        #expect(await waitUntil { await fixture.bikeRepository.tractionWrites.count == 1 })
        #expect(await fixture.bikeRepository.tractionWrites == [
            .init(mapIndex: 0, powerTractionPercent: 35, brakingTractionPercent: 0)
        ])
        #expect(fixture.viewModel.viewState.adjustments[2].value == 35)
        #expect(fixture.viewModel.viewState.adjustments[3].value == 0)
        fixture.viewModel.stop()
    }

    @Test("Firmware compatibility is required even when traction values are present")
    func incompatibleTractionFirmware() async {
        let repository = PowerModeSettingsBikeRepository()
        await repository.setTractionCompatibility(.init(firmware: "1.10.0", isCompatible: false))
        let fixture = makePowerModeSettingsFixture(bikeRepository: repository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.adjustments[0].isEnabled })
        #expect(!fixture.viewModel.viewState.adjustments[2].isEnabled)
        #expect(!fixture.viewModel.viewState.adjustments[3].isEnabled)
        #expect(await waitUntil {
            fixture.viewModel.viewState.controlGroups[1].detail == "Available with supported firmware."
        })
        fixture.viewModel.updateAdjustment(id: .powerTraction, value: 30)
        #expect(await repository.requestedTractionWrites.isEmpty)
        fixture.viewModel.stop()
    }

    @Test("A late firmware result cannot re-enable traction after disconnect")
    func lateTractionCompatibility() async {
        let operation = ControllablePowerModeSettingsOperation()
        let repository = PowerModeSettingsBikeRepository(tractionCompatibilityOperation: operation)
        let fixture = makePowerModeSettingsFixture(bikeRepository: repository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { await operation.pendingCount == 1 })
        #expect(!fixture.viewModel.viewState.adjustments[2].isEnabled)
        #expect(fixture.viewModel.viewState.controlGroups[1].detail == nil)
        await fixture.vehicleSession.send(.init(
            connection: .init(state: .disconnected(reason: "Connection lost")),
            profile: .init(vin: vin)
        ))
        #expect(await waitUntil { fixture.viewModel.viewState.connectionText == "Bike disconnected" })
        await operation.succeedAll()
        await repository.setTractionCompatibility(.init(firmware: "1.10.0", isCompatible: false))
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { await operation.pendingCount == 1 })
        #expect(!fixture.viewModel.viewState.adjustments[2].isEnabled)
        #expect(fixture.viewModel.viewState.controlGroups[1].detail == nil)
        await operation.succeedAll()
        #expect(await waitUntil {
            fixture.viewModel.viewState.controlGroups[1].detail == "Available with supported firmware."
        })
        #expect(!fixture.viewModel.viewState.adjustments[2].isEnabled)
        #expect(await repository.requestedTractionWrites.isEmpty)
        await fixture.viewModel.stopAndWait()
    }

    @Test("A firmware read failure hides the incompatibility notice and can be refreshed")
    func failedTractionCompatibility() async {
        let repository = PowerModeSettingsBikeRepository()
        await repository.setTractionCompatibilityError(BikeTractionControlError.confirmationUnavailable)
        let fixture = makePowerModeSettingsFixture(bikeRepository: repository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.adjustments[0].isEnabled })
        #expect(await repository.tractionCompatibilityReads == 1)
        #expect(!fixture.viewModel.viewState.adjustments[2].isEnabled)
        #expect(fixture.viewModel.viewState.controlGroups[1].detail == nil)
        await repository.setTractionCompatibilityError(nil)
        fixture.viewModel.refresh()
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        #expect(await repository.tractionCompatibilityReads == 2)
        #expect(await repository.requestedTractionWrites.isEmpty)
        fixture.viewModel.stop()
    }

    @Test("Traction can be retried at the same value without refreshing")
    func tractionRetry() async {
        let repository = PowerModeSettingsBikeRepository()
        let fixture = makePowerModeSettingsFixture(bikeRepository: repository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        await repository.setTractionError(BikeTractionControlError.confirmationUnavailable)
        fixture.viewModel.updateAdjustment(id: .powerTraction, value: 35)
        #expect(await waitUntil { feedback(for: .powerTraction, in: fixture.viewModel).state == .failed })
        #expect(fixture.viewModel.viewState.adjustments[2].value == 35)
        #expect(fixture.viewModel.viewState.adjustments[2].isEnabled)
        #expect(fixture.viewModel.viewState.adjustments[2].allowsUnchangedCommit)
        await repository.setTractionError(nil)
        fixture.viewModel.updateAdjustment(id: .powerTraction, value: 35)
        #expect(await waitUntil { feedback(for: .powerTraction, in: fixture.viewModel).state == .confirmed })
        #expect(await repository.tractionWrites.count == 1)
        fixture.viewModel.stop()
    }

    @Test("Traction remains usable with no base configuration", arguments: [false, true])
    func tractionWithoutBase(partial: Bool) async {
        let fixture = makePowerModeSettingsFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(.init(
            telemetry: .init(powerModeConfigurations:
                partial ? [0: .init(mapIndex: 0, powerTractionPercent: 20)] : [:]
            ),
            connection: connectedSnapshot().connection, profile: connectedSnapshot().profile,
            isCanonicalTelemetryAvailable: true
        ))
        #expect(await waitUntil { fixture.viewModel.viewState.adjustments[2].isEnabled })
        #expect(!fixture.viewModel.viewState.adjustments[0].isEnabled)
        #expect(fixture.viewModel.viewState.adjustments[2].value == (partial ? 20 : 0))
        #expect(fixture.viewModel.viewState.adjustments[3].value == 0)
        fixture.viewModel.updateAdjustment(id: .brakingTraction, value: 40)
        #expect(await waitUntil { await fixture.bikeRepository.tractionWrites.count == 1 })
        #expect(await fixture.bikeRepository.tractionWrites == [
            .init(mapIndex: 0, powerTractionPercent: partial ? 20 : 0, brakingTractionPercent: 40)
        ])
        fixture.viewModel.stop()
    }

    @Test("A stale baseline updates both controls and waits for another gesture")
    func changedTractionBaseline() async {
        let repository = PowerModeSettingsBikeRepository()
        let fixture = makePowerModeSettingsFixture(bikeRepository: repository)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        await repository.setTractionError(BikeTractionControlError.changed(
            .init(mapIndex: 0, powerRaw: 100, brakingRaw: 300)
        ))
        fixture.viewModel.updateAdjustment(id: .powerTraction, value: 35)
        #expect(await waitUntil { feedback(for: .powerTraction, in: fixture.viewModel).state == .failed })
        #expect(fixture.viewModel.viewState.adjustments[2].value == 10)
        #expect(fixture.viewModel.viewState.adjustments[3].value == 30)
        #expect(await repository.tractionWrites.isEmpty)
        fixture.viewModel.stop()
    }

    @Test("Base-control feedback is not masked by an earlier traction confirmation")
    func baseFeedbackAfterTraction() async {
        let fixture = makePowerModeSettingsFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(connectedSnapshot())
        #expect(await waitUntil { controlsAreEnabled(fixture.viewModel) })
        fixture.viewModel.updateAdjustment(id: .powerTraction, value: 35)
        #expect(await waitUntil { feedback(for: .powerTraction, in: fixture.viewModel).state == .confirmed })
        fixture.viewModel.updateAdjustment(id: .power, value: 50)
        #expect(await waitUntil { feedback(for: .power, in: fixture.viewModel).state == .confirmed })
        #expect(feedback(for: .powerTraction, in: fixture.viewModel).state == .idle)
        fixture.viewModel.stop()
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

    private func feedback(
        for id: PowerModeAdjustmentID,
        in viewModel: PowerModeSettingsViewModel
    ) -> PowerModeControlFeedback {
        viewModel.viewState.adjustments.first { $0.id == id }?.feedback ?? .idle
    }

}
