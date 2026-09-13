import Foundation
import WatchCompanionDomain

@MainActor
final class WatchCompanionPreviewSession: CompanionSession {
    private let scenario: String
    private var observers: [UUID: AsyncStream<CompanionState>.Continuation] = [:]

    init(scenario: String) { self.scenario = scenario }
    func activate() {}
    func requestLatest() {
        for observer in observers.values { observer.yield(state) }
    }

    func observe() -> AsyncStream<CompanionState> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<CompanionState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observers[identifier] = continuation
        continuation.yield(state)
        continuation.onTermination = { [weak self] _ in
            DispatchQueue.main.async { self?.observers.removeValue(forKey: identifier) }
        }
        return stream
    }

    private var state: CompanionState {
        let charging = scenario.contains("charging")
        let stale = scenario.contains("stale")
        return CompanionState(
            snapshot: CompanionSnapshot(
                generatedAt: Date(), telemetryAt: Date().addingTimeInterval(stale ? -120 : 0),
                bikeConnected: true, isCharging: charging,
                batteryPercent: charging ? 88 : 38, mapIndex: 4, mapName: "Trail",
                activity: scenario.contains("off") ? .off : (charging ? .charging : .riding), tractionPercent: 12,
                chargingPowerWatts: 1_000, chargingCurrentAmperes: 2.6, chargeRemainingSeconds: 3_060
            ),
            isReachable: !stale
        )
    }
}
