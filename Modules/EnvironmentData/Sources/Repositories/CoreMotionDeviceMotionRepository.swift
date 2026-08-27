@preconcurrency import CoreMotion
import EnvironmentDomain
import Foundation
import OSLog

public actor CoreMotionDeviceMotionRepository: DeviceMotionRepository {
    private let motionManager: CMMotionManager
    private let operationQueue: OperationQueue
    private let now: @Sendable () -> Date
    private var continuations: [UUID: AsyncStream<DeviceMotionSample>.Continuation] = [:]

    public init(
        motionManager: CMMotionManager,
        operationQueue: OperationQueue,
        now: @escaping @Sendable () -> Date
    ) {
        self.motionManager = motionManager
        self.operationQueue = operationQueue
        self.now = now
        operationQueue.name = "com.fenr.device-motion"
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }

    public func observeDeviceMotion() -> AsyncStream<DeviceMotionSample> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuations[id] = continuation
            startUpdatesIfNeeded()
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }
}

private extension CoreMotionDeviceMotionRepository {
    func startUpdatesIfNeeded() {
        guard !motionManager.isDeviceMotionActive else { return }
        guard motionManager.isDeviceMotionAvailable else {
            Constants.logger.error("Device motion is unavailable on this device")
            return
        }
        motionManager.deviceMotionUpdateInterval = Constants.updateInterval
        motionManager.startDeviceMotionUpdates(
            using: preferredReferenceFrame,
            to: operationQueue
        ) { [weak self] motion, error in
            if let error {
                Constants.logger.error("Device motion update failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let motion else { return }
            Task { await self?.receive(motion) }
        }
    }

    func receive(_ motion: CMDeviceMotion) {
        let quaternion = motion.attitude.quaternion
        let sample = DeviceMotionSample(
            attitude: .init(
                xComponent: quaternion.x,
                yComponent: quaternion.y,
                zComponent: quaternion.z,
                scalarComponent: quaternion.w
            ),
            magneticHeadingDegrees: validHeading(motion.heading),
            magneticAccuracy: accuracy(motion.magneticField.accuracy),
            observedAt: now()
        )
        guard sample.isFinite else { return }
        continuations.values.forEach { $0.yield(sample) }
    }

    func removeContinuation(_ id: UUID) {
        continuations[id] = nil
        guard continuations.isEmpty else { return }
        motionManager.stopDeviceMotionUpdates()
    }

    var preferredReferenceFrame: CMAttitudeReferenceFrame {
        let available = CMMotionManager.availableAttitudeReferenceFrames()
        if available.contains(.xMagneticNorthZVertical) {
            return .xMagneticNorthZVertical
        }
        if available.contains(.xArbitraryCorrectedZVertical) {
            return .xArbitraryCorrectedZVertical
        }
        return .xArbitraryZVertical
    }

    func validHeading(_ heading: Double) -> Double? {
        heading.isFinite && heading >= .zero ? heading : nil
    }

    func accuracy(_ accuracy: CMMagneticFieldCalibrationAccuracy) -> MotionAccuracy {
        switch accuracy {
        case .uncalibrated: .unreliable
        case .low: .low
        case .medium: .medium
        case .high: .high
        @unknown default: .unavailable
        }
    }

    enum Constants {
        static let updateInterval: TimeInterval = 1.0 / 20.0
        static let logger = Logger(subsystem: "com.fenr.app", category: "DeviceMotion")
    }
}
