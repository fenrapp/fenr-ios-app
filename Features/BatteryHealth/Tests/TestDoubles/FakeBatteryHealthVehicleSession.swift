import BikeDomain
import Foundation
import VehicleSession

actor FakeBatteryHealthVehicleSession: VehicleSessionService {
    private let repository: any BikeBatteryHealthRepository

    init(repository: any BikeBatteryHealthRepository) {
        self.repository = repository
    }

    func observe() -> AsyncStream<VehicleSessionSnapshot> {
        let repository = repository
        return AsyncStream { continuation in
            let task = Task {
                let stream = await repository.observeBatteryHealth()
                for await health in stream {
                    guard !Task.isCancelled else { return }
                    continuation.yield(.init(
                        batteryHealth: health,
                        batteryHealthMonitoringState: .active
                    ))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func calibrateDeviceMotion() {}

    func setBatteryHealthMonitoringRequired(_ required: Bool, consumerID _: UUID) async {
        if required {
            try? await repository.startBatteryHealthMonitoring()
        } else {
            await repository.stopBatteryHealthMonitoring()
        }
    }
}
