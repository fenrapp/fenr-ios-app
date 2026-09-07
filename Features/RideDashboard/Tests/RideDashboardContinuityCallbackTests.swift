@testable import RideDashboard
import Testing

@MainActor
struct RideDashboardContinuityCallbackTests {
    @Test("Continuity changes apply card lifecycle before returning to the caller")
    func cardLifecyclesChangeSynchronously() {
        let fixture = RideDashboardFeatureTestFixture.make()
        defer { fixture.feature.invalidateSession() }
        fixture.feature.setPresentationActive(true)
        fixture.feature.synchronizeCardLifecycles(centerMode: .riding, selection: .init())
        #expect(!fixture.range.isObservingForTesting)

        fixture.dashboard.viewModel.setPreviewState(.init(continuityPhase: .live))
        #expect(fixture.range.isObservingForTesting)
        #expect(fixture.bikeLock.isObservingForTesting)

        fixture.dashboard.viewModel.setPreviewState(.init(continuityPhase: .recovering))
        #expect(!fixture.range.isObservingForTesting)
        #expect(fixture.bikeLock.isObservingForTesting)

        fixture.dashboard.viewModel.setPreviewState(.init(continuityPhase: .terminal))
        #expect(!fixture.range.isObservingForTesting)
        #expect(!fixture.bikeLock.isObservingForTesting)

        fixture.feature.setPresentationActive(false)
        fixture.dashboard.viewModel.setPreviewState(.init(continuityPhase: .live))
        #expect(!fixture.range.isObservingForTesting)
        #expect(!fixture.bikeLock.isObservingForTesting)
    }

    @Test("Presentation changes in the same phase do not emit duplicate continuity commands")
    func emitsOnlyContinuityTransitions() {
        let recorder = DashboardContinuityRecorder()
        let fixture = makeFixture(onContinuityChanged: recorder.record)
        fixture.viewModel.setPreviewState(.init(continuityPhase: .live))
        #expect(recorder.phases == [.live])
        fixture.viewModel.setPreviewState(.init(connectionDetail: "Updated telemetry", continuityPhase: .live))
        #expect(recorder.phases == [.live])
        fixture.viewModel.setPreviewState(.init(continuityPhase: .recovering))
        fixture.viewModel.setPreviewState(.init(continuityPhase: .terminal))
        fixture.viewModel.invalidateSession()
        #expect(recorder.phases == [.live, .recovering, .terminal, .cold])
    }
}
