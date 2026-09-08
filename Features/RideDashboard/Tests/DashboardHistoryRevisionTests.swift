import Testing
import TestSupport

@MainActor
@Suite("Dashboard history revisions")
struct DashboardHistoryRevisionTests {
    @Test("An obsolete revision does not publish data or errors", arguments: DashboardHistoryCardKind.allCases)
    func rejectsObsoleteRevision(kind: DashboardHistoryCardKind) async {
        let fixture = DashboardHistoryCardFixture(kind: kind)
        fixture.show()
        #expect(await waitUntil { await fixture.repository.completedReadCount() == 1 })
        await fixture.loadTask()?.value
        for shouldFail in [false, true] {
            let revision = shouldFail ? 3 : 1
            await fixture.repository.replaceCompletedTrips(with: [])
            await fixture.repository.setReadError(shouldFail ? .readFailed : nil)
            await fixture.repository.blockNextRead()
            await fixture.session.send(DashboardHistoryCardData.snapshot(revision: revision))
            #expect(await waitUntil { await fixture.repository.hasBlockedRead() })
            let obsoleteLoad = fixture.loadTask()
            await fixture.session.send(DashboardHistoryCardData.snapshot(
                revision: revision + 1, measurementSystem: .imperial
            ))
            #expect(await waitUntil { fixture.measurementUnit().contains("mi") })
            let previous = fixture.displayedHistory()
            await fixture.repository.replaceCompletedTrips(with: [DashboardHistoryCardData.trip()])
            await fixture.repository.setReadError(nil)
            await fixture.repository.blockNextRead()
            await fixture.repository.releaseRead()
            await obsoleteLoad?.value
            #expect(await waitUntil { await fixture.repository.hasBlockedRead() })
            #expect(fixture.error() == nil)
            #expect(fixture.displayedHistory() == previous)
            let latestLoad = fixture.loadTask()
            await fixture.repository.releaseRead()
            await latestLoad?.value
        }
        fixture.stop()
    }
}
