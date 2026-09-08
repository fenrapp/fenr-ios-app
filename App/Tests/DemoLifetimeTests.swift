import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Demo graph lifetime")
struct DemoLifetimeTests {
    @Test("Repeated demo exits release active dashboard, diagnostics and battery owners")
    func repeatedExitsReleaseFeatureOwners() async throws {
        let fixture = DemoExperienceTestFixture()
        do {
            for cycle in 1...3 {
                let probes = try await DemoLifetimeTestCycle(fixture: fixture).run()
                let released = await waitUntil(timeout: .seconds(3)) {
                    probes.allSatisfy { $0.object == nil }
                }
                let retainedNames = probes.filter { $0.object != nil }.map(\.name).joined(separator: ", ")
                #expect(released, "Cycle \(cycle) retained: \(retainedNames)")
            }
            try await fixture.factory.discard(identity: fixture.identity)
            try FileManager.default.removeItem(at: fixture.directory)
        } catch {
            try? await fixture.factory.discard(identity: fixture.identity)
            try? FileManager.default.removeItem(at: fixture.directory)
            throw error
        }
    }
}
