import Foundation
import RideSession
import TestSupport
import VehicleSession

actor RideDynamicsTestRideSession: RideSessionService {
    private let hub = TestEventHub<RideSessionSnapshot>(bufferingPolicy: .unbounded)

    func observe() async -> AsyncStream<RideSessionSnapshot> {
        await hub.stream(replay: .init(
            vehicleIdentity: .vin("FENRTEST000000001"),
            motion: .init(
                rollDegrees: 0,
                pitchDegrees: 0,
                availability: .available,
                observedAt: .init(timeIntervalSinceReferenceDate: 1)
            ),
            isCanonicalTelemetryAvailable: true
        ))
    }

    func start() {}
    func stop() {}
    func persistCurrentTrip() {}
    func completeCurrentTrip() {}
    func flush() {}
    func togglePauseCurrentTrip() {}
    func resetCurrentTrip() {}

    func send(_ snapshot: RideSessionSnapshot) async {
        await hub.send(snapshot)
    }

    func waitForSubscriber() async -> Bool {
        await hub.waitForSubscriber()
    }
}

actor RideDynamicsTestVehicleSession: VehicleSessionService {
    private var locationRequests: [Bool] = []
    private var locationContinuations: [CheckedContinuation<Void, Never>] = []
    private var shouldBlockNextLocationRequest = false
    private var calibrationRequestCount = 0
    private var completedCalibrationCount = 0
    private var calibrationContinuations: [CheckedContinuation<Void, Never>] = []
    private var shouldBlockNextCalibration = false

    func observe() -> AsyncStream<VehicleSessionSnapshot> {
        AsyncStream { continuation in
            continuation.yield(.init(
                telemetry: .init(lastUpdated: .init(timeIntervalSinceReferenceDate: 1)),
                connection: .init(state: .receivingTelemetry(peripheralName: "TEST"))
            ))
        }
    }

    func start() {}
    func stop() {}
    func refreshBikeStatus() {}

    func zeroBikeAttitude() async {
        calibrationRequestCount += 1
        if shouldBlockNextCalibration {
            shouldBlockNextCalibration = false
            await withCheckedContinuation { continuation in
                calibrationContinuations.append(continuation)
            }
        }
        completedCalibrationCount += 1
    }

    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}

    func setLocationMonitoringRequired(_ required: Bool, consumerID _: UUID) async {
        locationRequests.append(required)
        if shouldBlockNextLocationRequest {
            shouldBlockNextLocationRequest = false
            await withCheckedContinuation { continuation in
                locationContinuations.append(continuation)
            }
        }
    }

    func blockNextLocationRequest() {
        shouldBlockNextLocationRequest = true
    }

    func recordedLocationRequests() -> [Bool] {
        locationRequests
    }

    func pendingLocationRequestCount() -> Int {
        locationContinuations.count
    }

    func releaseNextLocationRequest() {
        guard !locationContinuations.isEmpty else { return }
        locationContinuations.removeFirst().resume()
    }

    func blockNextCalibration() {
        shouldBlockNextCalibration = true
    }

    func recordedCalibrationRequestCount() -> Int {
        calibrationRequestCount
    }

    func recordedCompletedCalibrationCount() -> Int {
        completedCalibrationCount
    }

    func releaseNextCalibration() {
        guard !calibrationContinuations.isEmpty else { return }
        calibrationContinuations.removeFirst().resume()
    }
}
