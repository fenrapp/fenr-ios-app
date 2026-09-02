import BikeDomain
import Foundation
import VehicleSession

actor FakeBatteryHealthVehicleSession: VehicleSessionService {
    private let repository: any BikeBatteryHealthRepository
    private let monitoringState: VehicleBatteryHealthMonitoringState

    init(
        repository: any BikeBatteryHealthRepository,
        monitoringState: VehicleBatteryHealthMonitoringState = .active
    ) {
        self.repository = repository
        self.monitoringState = monitoringState
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
                        batteryHealthMonitoringState: monitoringState
                    ))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func zeroBikeAttitude() {}

    func setBatteryHealthMonitoringRequired(_ required: Bool, consumerID _: UUID) async {
        if required {
            try? await repository.startBatteryHealthMonitoring()
        } else {
            await repository.stopBatteryHealthMonitoring()
        }
    }
}
