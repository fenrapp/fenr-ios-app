import BikeDomain
import Foundation
import VehicleSession

actor FakeBatteryHealthVehicleSession: VehicleSessionService {
    private let repository: any BikeBatteryHealthRepository
    private var monitoringState: VehicleBatteryHealthMonitoringState
    private var profile: BikeProfile?
    private var hasReceivedProfile = false
    private var connection = BikeConnection()

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
                    continuation.yield(self.snapshot(health: health))
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

    func setProfile(_ profile: BikeProfile?) {
        self.profile = profile
        hasReceivedProfile = true
    }

    func setConnection(_ state: ConnectionState) {
        connection.state = state
    }

    private func snapshot(health: BikeBatteryHealth) -> VehicleSessionSnapshot {
        .init(
            connection: connection,
            profile: profile,
            batteryHealth: health,
            batteryHealthMonitoringState: monitoringState,
            hasReceivedProfile: hasReceivedProfile
        )
    }
}
