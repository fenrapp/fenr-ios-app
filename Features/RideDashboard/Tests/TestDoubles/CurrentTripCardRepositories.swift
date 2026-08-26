import BikeDomain
import EnvironmentDomain
import Foundation
import RideSessionDomain
import SettingsDomain
import TestSupport

actor CurrentTripCardBikeRepository: BikeRepository {
    private let telemetryHub = TestEventHub<BikeTelemetry>()
    private let connectionHub = TestEventHub<BikeConnection>()

    func start() async {}
    func stop() async {}
    func connect(vin _: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}

    func observeTelemetry() async -> AsyncStream<BikeTelemetry> {
        await telemetryHub.stream()
    }

    func observeConnection() async -> AsyncStream<BikeConnection> {
        await connectionHub.stream()
    }

    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> {
        AsyncStream { _ in }
    }

    func sendTelemetry(_ telemetry: BikeTelemetry) async {
        await telemetryHub.waitForSubscriber()
        await telemetryHub.send(telemetry)
    }

    func sendConnection(_ connection: BikeConnection) async {
        await connectionHub.waitForSubscriber()
        await connectionHub.send(connection)
    }
}

actor CurrentTripCardSettingsRepository: AppSettingsRepository {
    private let settings: AppSettings

    init(speedSource: SpeedSource = .motorcycle) {
        settings = .init(
            speedSource: speedSource,
            measurementSystem: .metric
        )
    }

    func load() -> AppSettings { settings }
    func save(_: AppSettings) {}
    func observe() -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(settings)
        }
    }
}

actor CurrentTripCardDeviceSpeedRepository: DeviceSpeedRepository {
    private let speedHub = TestEventHub<DeviceSpeedSample>()

    func observeDeviceSpeed() async -> AsyncStream<DeviceSpeedSample> {
        await speedHub.stream()
    }

    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .authorized }
    func requestLocationAuthorization() {}

    func send(_ sample: DeviceSpeedSample) async {
        await speedHub.waitForSubscriber()
        await speedHub.send(sample)
    }
}

actor CurrentTripCardTripRepository: RideTripRepository {
    private var activeTrip: RideTrip?
    private var completedTrips: [RideTrip]
    private var completedTripLoadCount = 0

    init(completedTrips: [RideTrip] = []) {
        self.completedTrips = completedTrips
    }

    func prepare(applicationSessionID: UUID) -> RideTrip? {
        guard activeTrip?.applicationSessionID == applicationSessionID else { return nil }
        return activeTrip
    }

    func saveActiveTrip(_ trip: RideTrip) {
        activeTrip = trip
    }

    func completeTrip(_ trip: RideTrip, at date: Date) {
        activeTrip = nil
        completedTrips.removeAll { $0.id == trip.id }
        completedTrips.append(trip.completed(at: date))
    }

    func loadCompletedTrips() -> [RideTrip] {
        completedTripLoadCount += 1
        return completedTrips
    }

    func currentActiveTrip() -> RideTrip? { activeTrip }
    func completionCount() -> Int { completedTrips.count }
    func loadCount() -> Int { completedTripLoadCount }

    func replaceCompletedTrips(_ trips: [RideTrip]) {
        completedTrips = trips
    }
}

@MainActor
final class CurrentTripHistoryChangeRecorder {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
