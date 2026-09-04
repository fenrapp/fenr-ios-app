import Foundation
import MaintenanceDomain
@testable import MaintenanceLog
import Testing
import TestSupport

@MainActor
struct MaintenanceViewModelTests {
    @Test("Localized suggested values can be saved without changing their formatting")
    func savesLocalizedValues() async throws {
        let fixture = MaintenanceTestFactory.make(locale: Locale(identifier: "es_ES"))
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        var draft = fixture.viewModel.makeDraft(id: nil)
        draft.odometerText = "12.345,6"
        draft.costText = "1.234,56"
        draft.currencyCode = "USD"

        fixture.viewModel.save(draft) {}

        #expect(await waitUntil { !fixture.viewModel.isMutating })
        let saved = try #require(await fixture.repository.savedEntries.last)
        #expect(saved.odometerKilometers == 12_345.6)
        #expect(saved.costMinorUnits == 123_456)
        #expect(saved.currencyCode == "USD")
        fixture.viewModel.stop()
    }

    @Test("Huge costs and future service dates are rejected without starting a save")
    func rejectsUnsafeValues() async {
        let fixture = MaintenanceTestFactory.make()
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        var hugeCost = fixture.viewModel.makeDraft(id: nil)
        hugeCost.costText = "999999999999999999999999999999999999"
        fixture.viewModel.save(hugeCost) {}
        #expect(fixture.viewModel.viewState.errorMessage != nil)

        fixture.viewModel.dismissError()
        var future = fixture.viewModel.makeDraft(id: nil)
        future.performedAt = MaintenanceTestFactory.now.addingTimeInterval(60)
        fixture.viewModel.save(future) {}

        #expect(fixture.viewModel.viewState.errorMessage != nil)
        #expect(await fixture.operation.requestCount(.save) == 0)
        fixture.viewModel.stop()
    }

    @Test("A bike change during save cannot navigate or replace the new bike state")
    func rejectsStaleSavePresentation() async {
        let secondBikeEntry = MaintenanceEntry(
            vin: MaintenanceTestFactory.Constants.secondVIN,
            selection: .init(kind: .tires),
            performedAt: MaintenanceTestFactory.now.addingTimeInterval(-100)
        )
        let fixture = MaintenanceTestFactory.make(entries: [secondBikeEntry])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        await fixture.operation.blockNext(.save)
        var didNavigate = false

        fixture.viewModel.save(fixture.viewModel.makeDraft(id: nil)) { didNavigate = true }
        await fixture.operation.waitForRequest(.save)
        await fixture.session.send(MaintenanceTestFactory.snapshot(vin: MaintenanceTestFactory.Constants.secondVIN))
        await fixture.operation.release(.save)

        #expect(await waitUntil { !fixture.viewModel.isMutating && fixture.viewModel.viewState.history.count == 1 })
        #expect(fixture.viewModel.viewState.history.first?.id == secondBikeEntry.id)
        #expect(!didNavigate)
        fixture.viewModel.stop()
    }

    @Test("Duplicate saves are ignored and stop cancels presentation work")
    func serializesAndStopsSave() async {
        let fixture = MaintenanceTestFactory.make()
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        await fixture.operation.blockNext(.save)
        var didNavigate = false
        let draft = fixture.viewModel.makeDraft(id: nil)

        fixture.viewModel.save(draft) { didNavigate = true }
        await fixture.operation.waitForRequest(.save)
        fixture.viewModel.save(draft) { didNavigate = true }
        #expect(await fixture.operation.requestCount(.save) == 1)
        #expect(fixture.viewModel.viewState.errorMessage == nil)

        fixture.viewModel.stop()
        await fixture.operation.release(.save)
        #expect(await waitUntil { !fixture.viewModel.isMutating })
        #expect(!didNavigate)
    }

    @Test("Official interval action is offered only when a recurring schedule exists")
    func exposesApplicableOfficialIntervals() {
        let fixture = MaintenanceTestFactory.make()

        #expect(fixture.viewModel.hasOfficialSchedule(kindID: MaintenanceKind.forkOil.rawValue))
        #expect(!fixture.viewModel.hasOfficialSchedule(kindID: MaintenanceKind.breakInGearOil.rawValue))
        #expect(!fixture.viewModel.hasOfficialSchedule(kindID: MaintenanceKind.chainLubrication.rawValue))
    }
}
