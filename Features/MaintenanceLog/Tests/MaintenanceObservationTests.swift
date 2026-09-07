import MaintenanceDomain
@testable import MaintenanceLog
import Observation
import Testing
import TestSupport

@MainActor
struct MaintenanceObservationTests {
    @Test("A detail-only observation invalidates when refresh replaces the persisted entry")
    func observesRefreshedDetail() async throws {
        var entry = MaintenanceEntry(
            vin: MaintenanceTestFactory.Constants.firstVIN,
            selection: .init(kind: .tires),
            performedAt: MaintenanceTestFactory.now,
            notes: "Before service"
        )
        let fixture = MaintenanceTestFactory.make(entries: [entry])
        defer { fixture.viewModel.stop() }
        fixture.viewModel.start()
        try #require(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        let id = entry.id
        let recorder = ObservationChangeRecorder()
        withObservationTracking {
            _ = fixture.viewModel.detail(id: id)
        } onChange: {
            recorder.record()
        }
        entry.notes = "After service"
        #expect(await fixture.repository.save(entry))
        fixture.viewModel.refresh()
        try #require(await waitUntil {
            fixture.viewModel.detail(id: id)?.fields.first { $0.id == "notes" }?.value == "After service"
        })
        #expect(recorder.count == 1)
        await fixture.viewModel.stopAndWait()
    }

    @Test("A detail-only observation invalidates on unit changes without reloading entries")
    func observesDetailMeasurementSystem() async throws {
        let entry = MaintenanceEntry(
            vin: MaintenanceTestFactory.Constants.firstVIN,
            selection: .init(kind: .tires),
            performedAt: MaintenanceTestFactory.now,
            odometerKilometers: 100
        )
        let fixture = MaintenanceTestFactory.make(entries: [entry])
        defer { fixture.viewModel.stop() }
        fixture.viewModel.start()
        try #require(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        let metric = try #require(fixture.viewModel.detail(id: entry.id))
        let initialLoadCount = await fixture.operation.requestCount(.load)
        let recorder = ObservationChangeRecorder()
        withObservationTracking {
            _ = fixture.viewModel.detail(id: entry.id)
        } onChange: {
            recorder.record()
        }
        await fixture.session.send(MaintenanceTestFactory.snapshot(
            vin: MaintenanceTestFactory.Constants.firstVIN, measurementSystem: .imperial
        ))
        try #require(await waitUntil {
            fixture.viewModel.detail(id: entry.id)?.fields.first { $0.id == "odometer" }?.value.contains("mi") == true
        })
        #expect(fixture.viewModel.detail(id: entry.id) != metric)
        #expect(recorder.count == 1)
        #expect(await fixture.operation.requestCount(.load) == initialLoadCount)
        await fixture.viewModel.stopAndWait()
    }
}
