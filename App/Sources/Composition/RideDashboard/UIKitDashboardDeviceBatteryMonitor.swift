import Foundation
import RideDashboard
import UIKit

@MainActor
final class UIKitDashboardDeviceBatteryMonitor: DashboardDeviceBatteryMonitoring {
    private let device: UIDevice
    private let notificationCenter: NotificationCenter
    private var continuations: [UUID: AsyncStream<DashboardDeviceBatterySnapshot>.Continuation] = [:]
    private var observerTokens: [NSObjectProtocol] = []
    private var restoredMonitoringValue = false
    private var isStarted = false

    init(
        device: UIDevice,
        notificationCenter: NotificationCenter
    ) {
        self.device = device
        self.notificationCenter = notificationCenter
    }

    isolated deinit {
        stop()
        continuations.values.forEach { $0.finish() }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        restoredMonitoringValue = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        observerTokens = [
            notificationCenter.addObserver(
                forName: UIDevice.batteryLevelDidChangeNotification,
                object: device,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.publishCurrentSnapshot() }
            },
            notificationCenter.addObserver(
                forName: UIDevice.batteryStateDidChangeNotification,
                object: device,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.publishCurrentSnapshot() }
            }
        ]
        publishCurrentSnapshot()
    }

    func stop() {
        guard isStarted else { return }
        observerTokens.forEach(notificationCenter.removeObserver)
        observerTokens.removeAll()
        if !restoredMonitoringValue {
            device.isBatteryMonitoringEnabled = false
        }
        isStarted = false
    }

    func observe() -> AsyncStream<DashboardDeviceBatterySnapshot> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<DashboardDeviceBatterySnapshot>.makeStream()
        continuations[id] = continuation
        continuation.yield(currentSnapshot())
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.continuations[id] = nil
            }
        }
        return stream
    }

    private func publishCurrentSnapshot() {
        let snapshot = currentSnapshot()
        continuations.values.forEach { $0.yield(snapshot) }
    }

    private func currentSnapshot() -> DashboardDeviceBatterySnapshot {
        let level = Double(device.batteryLevel)
        return DashboardDeviceBatterySnapshot(
            level: level >= .zero ? level : nil,
            isCharging: device.batteryState == .charging || device.batteryState == .full
        )
    }
}
