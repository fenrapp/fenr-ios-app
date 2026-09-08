import Foundation
import MaintenanceDomain
@testable import MaintenanceLog
import Testing
import TestSupport

@MainActor
struct MaintenanceReadFailureTests {
    @Test("Deferred reminder authorization survives reopening the same bike")
    func deferredReminderAuthorizationSurvivesRestart() async {
        let fixture = MaintenanceTestFactory.make()
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        await fixture.repository.failNextLoad()
        var draft = fixture.viewModel.makeDraft(id: nil)
        draft.hasDateReminder = true
        draft.dueDate = MaintenanceTestFactory.now.addingTimeInterval(3_600)
        fixture.viewModel.save(draft) {}
        #expect(await waitUntil { fixture.viewModel.viewState.loadErrorMessage != nil })
        #expect(!fixture.viewModel.pendingReminderAuthorizationIDs.isEmpty)
        fixture.viewModel.stop()
        fixture.viewModel.start()
        #expect(await waitUntil { await fixture.reminders.scheduled.count == 1 })
        #expect(await fixture.reminders.scheduled.last?.requestedAuthorization == true)
        #expect(await waitUntil { fixture.viewModel.pendingReminderAuthorizationIDs.isEmpty })
        fixture.viewModel.refresh()
        #expect(await waitUntil { await fixture.reminders.scheduled.count == 2 })
        #expect(await fixture.reminders.scheduled.last?.requestedAuthorization == false)
        fixture.viewModel.stop()
    }

    @Test("Changing bikes clears deferred authorization without applying it to the new bike")
    func changingBikesClearsDeferredAuthorization() async {
        let fixture = MaintenanceTestFactory.make()
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        await fixture.repository.failNextLoad()
        var draft = fixture.viewModel.makeDraft(id: nil)
        draft.hasDateReminder = true
        draft.dueDate = MaintenanceTestFactory.now.addingTimeInterval(3_600)
        fixture.viewModel.save(draft) {}
        #expect(await waitUntil { !fixture.viewModel.pendingReminderAuthorizationIDs.isEmpty })
        await fixture.session.send(MaintenanceTestFactory.snapshot(vin: MaintenanceTestFactory.Constants.secondVIN))
        #expect(await waitUntil { fixture.viewModel.pendingReminderAuthorizationIDs.isEmpty })
        #expect(await fixture.reminders.scheduled.isEmpty)
        fixture.viewModel.stop()
    }

    @Test("A confirmed deletion revokes its reminder after the user changes bikes")
    func deletedReminderIsRevokedAfterBikeChange() async {
        let entry = MaintenanceEntry(
            vin: MaintenanceTestFactory.Constants.firstVIN,
            selection: .init(kind: .tires), performedAt: MaintenanceTestFactory.now
        )
        let fixture = MaintenanceTestFactory.make(entries: [entry])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.history.count == 1 })
        let cancellations = await fixture.reminders.cancelled.count
        await fixture.operation.blockNext(.delete)
        var didClose = false
        fixture.viewModel.delete(id: entry.id) { didClose = true }
        await fixture.operation.waitForRequest(.delete)
        await fixture.session.send(MaintenanceTestFactory.snapshot(vin: MaintenanceTestFactory.Constants.secondVIN))
        #expect(await waitUntil { !fixture.viewModel.isMutating && fixture.viewModel.viewState.history.isEmpty })
        await fixture.operation.release(.delete)
        #expect(await waitUntil { await fixture.reminders.cancelled.count == cancellations + 1 })
        #expect(await fixture.reminders.cancelled.last == entry.id)
        #expect(!didClose)
        #expect(fixture.viewModel.viewState.history.isEmpty)
        fixture.viewModel.stop()
    }

    @Test("An initial read error offers retry without claiming there are no records")
    func initialFailureCanRetry() async {
        let fixture = MaintenanceTestFactory.make()
        await fixture.repository.failNextLoad()
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .failed })
        #expect(fixture.viewModel.viewState.loadErrorMessage != nil)
        #expect(await fixture.reminders.scheduled.isEmpty)
        #expect(await fixture.reminders.cancelled.isEmpty)
        fixture.viewModel.refresh()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        #expect(fixture.viewModel.viewState.history.isEmpty)
        #expect(fixture.viewModel.viewState.loadErrorMessage == nil)
        fixture.viewModel.stop()
    }

    @Test("Failed refresh preserves current records and does not synchronize reminders")
    func failedRefreshPreservesRecords() async {
        let entry = MaintenanceEntry(
            vin: MaintenanceTestFactory.Constants.firstVIN,
            selection: .init(kind: .tires), performedAt: MaintenanceTestFactory.now
        )
        let fixture = MaintenanceTestFactory.make(entries: [entry])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.history.count == 1 })
        let cancellations = await fixture.reminders.cancelled.count
        await fixture.repository.failNextLoad()
        fixture.viewModel.refresh()
        #expect(await waitUntil { fixture.viewModel.viewState.loadErrorMessage != nil })
        #expect(fixture.viewModel.viewState.status == .loaded)
        #expect(fixture.viewModel.viewState.history.first?.id == entry.id)
        #expect(await fixture.reminders.cancelled.count == cancellations)
        #expect(await fixture.reminders.scheduled.isEmpty)
        fixture.viewModel.stop()
    }

    @Test("A confirmed save closes the form and remains visible when refreshing fails")
    func confirmedSaveSurvivesRefreshFailure() async throws {
        let fixture = MaintenanceTestFactory.make()
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        await fixture.repository.failNextLoad()
        var draft = fixture.viewModel.makeDraft(id: nil)
        draft.hasDateReminder = true
        draft.dueDate = MaintenanceTestFactory.now.addingTimeInterval(3_600)
        var didClose = false
        fixture.viewModel.save(draft) { didClose = true }
        #expect(await waitUntil { didClose && !fixture.viewModel.isMutating })
        let saved = try #require(await fixture.repository.savedEntries.last)
        #expect(fixture.viewModel.viewState.history.map(\.id) == [saved.id])
        #expect(fixture.viewModel.viewState.errorMessage == nil)
        #expect(fixture.viewModel.viewState.loadErrorMessage != nil)
        #expect(await fixture.reminders.scheduled.isEmpty)
        #expect(await fixture.reminders.cancelled.isEmpty)
        fixture.viewModel.refresh()
        #expect(await waitUntil { fixture.viewModel.viewState.loadErrorMessage == nil })
        #expect(await waitUntil { await fixture.reminders.scheduled.count == 1 })
        #expect(await fixture.reminders.scheduled.last?.requestedAuthorization == true)
        #expect(await waitUntil { fixture.viewModel.pendingReminderAuthorizationIDs.isEmpty })
        #expect(await fixture.repository.savedEntries.count == 1)
        fixture.viewModel.stop()
    }

    @Test("A confirmed deletion stays deleted when refreshing fails")
    func confirmedDeleteSurvivesRefreshFailure() async {
        let entry = MaintenanceEntry(
            vin: MaintenanceTestFactory.Constants.firstVIN,
            selection: .init(kind: .tires), performedAt: MaintenanceTestFactory.now
        )
        let fixture = MaintenanceTestFactory.make(entries: [entry])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.history.count == 1 })
        let cancellations = await fixture.reminders.cancelled.count
        await fixture.repository.failNextLoad()
        var didClose = false
        fixture.viewModel.delete(id: entry.id) { didClose = true }
        #expect(await waitUntil { didClose && !fixture.viewModel.isMutating })
        #expect(fixture.viewModel.viewState.history.isEmpty)
        #expect(fixture.viewModel.viewState.loadErrorMessage != nil)
        #expect(fixture.viewModel.viewState.errorMessage == nil)
        #expect(await fixture.reminders.cancelled.count == cancellations + 1)
        fixture.viewModel.stop()
    }

    @Test("Pending initial reads stay loading and late failures cannot affect a new bike")
    func lateReadFailureCannotAffectNewBike() async {
        let fixture = MaintenanceTestFactory.make()
        await fixture.repository.failNextLoad()
        await fixture.operation.blockNext(.load)
        fixture.viewModel.start()
        await fixture.operation.waitForRequest(.load)
        await fixture.session.send(MaintenanceTestFactory.snapshot(
            vin: MaintenanceTestFactory.Constants.firstVIN, measurementSystem: .imperial
        ))
        #expect(fixture.viewModel.viewState.status == .loading)
        await fixture.session.send(MaintenanceTestFactory.snapshot(vin: MaintenanceTestFactory.Constants.secondVIN))
        #expect(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        await fixture.operation.release(.load)
        #expect(fixture.viewModel.viewState.loadErrorMessage == nil)
        #expect(fixture.viewModel.viewState.history.isEmpty)
        fixture.viewModel.stop()
    }
}
