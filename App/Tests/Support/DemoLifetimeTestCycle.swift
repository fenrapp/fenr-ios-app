@testable import RideDashboard
import Testing
import TestSupport

@MainActor
struct DemoLifetimeTestCycle {
    let fixture: DemoExperienceTestFixture

    func run() async throws -> [WeakObjectProbe] {
        let experience = try await fixture.factory.make(identity: fixture.identity)
        let dashboard = experience.root.featureStore.rideDashboardFactory.makeFeature()
        do {
            let demo = try #require(experience.demoViewModel)
            let diagnostics = experience.root.featureStore.diagnosticsViewModel
            let battery = experience.root.featureStore.batteryHealthViewModel
            let probes = [
                WeakObjectProbe(name: "demo", object: demo),
                WeakObjectProbe(name: "dashboard feature", object: dashboard),
                WeakObjectProbe(name: "dashboard view model", object: dashboard.dashboardViewModel),
                WeakObjectProbe(name: "charging card", object: dashboard.chargingViewModel),
                WeakObjectProbe(name: "diagnostics", object: diagnostics),
                WeakObjectProbe(name: "battery health", object: battery),
                WeakObjectProbe(name: "app lifecycle", object: experience.root.lifecycleController),
                WeakObjectProbe(name: "setup flow", object: experience.root.setupFlow)
            ]
            await experience.root.lifecycleController.start()
            demo.select(id: "charging")
            dashboard.setPresentationActive(true)
            try #require(await waitUntil(timeout: .seconds(5)) {
                demo.viewState.selectedID == "charging"
                    && dashboard.dashboardViewModel.viewState.continuityPhase == .live
            })

            for _ in 0..<2 {
                diagnostics.setPresentationActive(true)
                battery.start()
                try #require(await waitUntil(timeout: .seconds(3)) {
                    diagnostics.viewState.isBLETraceCaptureAvailable && battery.viewState.isMonitoring
                })
                await diagnostics.stopAndWait()
                await battery.stopAndWait()
                #expect(!diagnostics.isPresentationActive)
                #expect(!battery.viewState.isMonitoring)
            }

            #expect(probes.allSatisfy { $0.object != nil })
            diagnostics.setPresentationActive(true)
            battery.start()
            try #require(await waitUntil(timeout: .seconds(3)) { battery.viewState.isMonitoring })
            dashboard.invalidateSession()
            await experience.close()
            return probes
        } catch {
            dashboard.invalidateSession()
            await experience.close()
            throw error
        }
    }
}
