import BikeEmulator
import Foundation

final class BikeDemoSelectionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var writes: [BikeEmulatorScenario] = []
    private var changes = 0

    var scenarios: [BikeEmulatorScenario] { lock.withLock { writes } }
    var observationCount: Int { lock.withLock { changes } }

    func record(_ scenario: BikeEmulatorScenario) {
        lock.withLock { writes.append(scenario) }
    }

    func recordObservation() {
        lock.withLock { changes += 1 }
    }
}
