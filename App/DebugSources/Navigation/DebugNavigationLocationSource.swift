import EnvironmentDomain
import Foundation
import Observation

@MainActor
@Observable
final class DebugNavigationLocationSource: DeviceSpeedRepository {
    private(set) var emittedSampleCount = 0
    private let clock: DebugNavigationClock
    @ObservationIgnored private var continuations: [UUID: AsyncStream<DeviceSpeedSample>.Continuation] = [:]

    init(clock: DebugNavigationClock) {
        self.clock = clock
    }

    deinit {
        continuations.values.forEach { $0.finish() }
    }

    func observeDeviceSpeed() async -> AsyncStream<DeviceSpeedSample> {
        let id = UUID()
        let pair = AsyncStream<DeviceSpeedSample>.makeStream()
        continuations[id] = pair.continuation
        pair.continuation.yield(sample(date: clock.now()))
        // Bounded subscriber cleanup deliberately outlives the stream consumer.
        pair.continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.continuations.removeValue(forKey: id) }
        }
        return pair.stream
    }

    func locationAuthorizationStatus() async -> LocationAuthorizationStatus { .authorized }
    func requestLocationAuthorization() async {}

    func advance() {
        emittedSampleCount += 1
        let next = sample(date: clock.advance())
        for (id, continuation) in continuations {
            if case .terminated = continuation.yield(next) { continuations.removeValue(forKey: id) }
        }
    }

    private func sample(date: Date) -> DeviceSpeedSample {
        DeviceSpeedSample(
            kilometersPerHour: 8,
            accuracyMetersPerSecond: 0.5,
            courseDegrees: 0,
            courseAccuracyDegrees: 1,
            altitudeMeters: 400,
            verticalAccuracyMeters: 1,
            horizontalAccuracyMeters: 1,
            coordinate: .init(
                latitudeDegrees: 40.426 + Double(emittedSampleCount) * 0.0002,
                longitudeDegrees: -3.703
            ),
            observedAt: date
        )
    }
}
