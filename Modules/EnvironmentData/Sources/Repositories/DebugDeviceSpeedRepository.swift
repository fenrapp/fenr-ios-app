import EnvironmentDomain
import Foundation
import RuntimeConfiguration

public actor DebugDeviceSpeedRepository: DeviceSpeedRepository {
    private var authorizationStatus: LocationAuthorizationStatus

    public init(authorizationStatus: LocationAuthorizationStatus = .authorized) {
        self.authorizationStatus = authorizationStatus
    }

    public func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> {
        AsyncStream { continuation in
            let task = Task {
                var index = 0
                while !Task.isCancelled {
                    let speeds = [8.0, 18.0, 34.0, 51.0, 41.0, 27.0]
                    continuation.yield(DeviceSpeedSample(
                        kilometersPerHour: speeds[index % speeds.count],
                        accuracyMetersPerSecond: 2,
                        observedAt: .now
                    ))
                    index += 1
                    try? await Task.sleep(for: FENRRuntimeConstants.Environment.debugDeviceSpeedUpdateInterval)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func locationAuthorizationStatus() -> LocationAuthorizationStatus {
        authorizationStatus
    }

    public func requestLocationAuthorization() {
        if authorizationStatus == .notDetermined {
            authorizationStatus = .authorized
        }
    }
}
