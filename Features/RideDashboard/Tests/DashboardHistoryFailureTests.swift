import Testing
import TestSupport

@MainActor
@Suite("Dashboard history read failures")
struct DashboardHistoryFailureTests {
    @Test("Failed loads show an error without retrying on telemetry", arguments: DashboardHistoryCardKind.allCases)
    func failedLoadsRequireRetry(kind: DashboardHistoryCardKind) async {
        let fixture = DashboardHistoryCardFixture(kind: kind)
        await fixture.repository.setReadError(.readFailed)
        fixture.show()
        #expect(await waitUntil { fixture.error() == "Unable to load saved ride data." })
        for _ in 0 ..< 20 {
            await fixture.session.send(DashboardHistoryCardData.snapshot())
        }
        await fixture.session.send(DashboardHistoryCardData.snapshot(measurementSystem: .imperial))
        #expect(await waitUntil { fixture.measurementUnit().contains("mi") })
        await fixture.loadTask()?.value
        #expect(await fixture.repository.loadCount() == 1)
        await fixture.repository.setReadError(nil)
        fixture.retry()
        #expect(await waitUntil { await fixture.repository.loadCount() == 2 && fixture.error() == nil })
        fixture.stop()
    }

    @Test("Refresh failure preserves data until a VIN change", arguments: DashboardHistoryCardKind.allCases)
    func refreshPreservesOnlyMatchingVehicle(kind: DashboardHistoryCardKind) async {
        let fixture = DashboardHistoryCardFixture(kind: kind)
        fixture.show()
        #expect(await waitUntil { await fixture.repository.completedReadCount() == 1 })
        await fixture.loadTask()?.value
        let previous = fixture.displayedHistory()
        await fixture.repository.setReadError(.invalidData)
        await fixture.session.send(DashboardHistoryCardData.snapshot(revision: 1))
        #expect(await waitUntil { fixture.error()?.contains("Showing previous data") == true })
        #expect(fixture.displayedHistory() == previous)
        await fixture.session.send(DashboardHistoryCardData.snapshot(
            vin: "FENRTEST000000002", isCanonical: false
        ))
        #expect(await waitUntil { fixture.displayedHistory() != previous && fixture.error() == nil })
        if kind != .range { #expect(fixture.historyIsLoading()) }
        fixture.stop()
    }

    @Test("A late old-vehicle result cannot restore its data", arguments: DashboardHistoryCardKind.allCases)
    func rejectsStaleCompletion(kind: DashboardHistoryCardKind) async {
        let fixture = DashboardHistoryCardFixture(kind: kind)
        await fixture.repository.blockNextRead()
        fixture.show()
        #expect(await waitUntil { await fixture.repository.hasBlockedRead() })
        let staleLoad = fixture.loadTask()
        await fixture.session.send(DashboardHistoryCardData.snapshot(vin: "FENRTEST000000002"))
        #expect(await waitUntil { await fixture.repository.loadCount() == 2 })
        await fixture.loadTask()?.value
        let replacement = fixture.displayedHistory()
        await fixture.repository.releaseRead()
        await staleLoad?.value
        #expect(await fixture.repository.completedReadCount() == 2)
        #expect(fixture.displayedHistory() == replacement)
        #expect(fixture.error() == nil)
        fixture.stop()
    }

    @Test("A new presentation retries a failed load once", arguments: DashboardHistoryCardKind.allCases)
    func presentationRetriesFailure(kind: DashboardHistoryCardKind) async {
        let fixture = DashboardHistoryCardFixture(kind: kind)
        await fixture.repository.setReadError(.readFailed)
        fixture.show()
        #expect(await waitUntil { fixture.error() != nil })
        fixture.hide()
        await fixture.repository.setReadError(nil)
        fixture.show()
        #expect(await waitUntil { await fixture.repository.loadCount() == 2 && fixture.error() == nil })
        fixture.stop()
    }
}
