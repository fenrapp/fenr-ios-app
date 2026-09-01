import Foundation

public struct RideRouteRecorder: Sendable {
    private var id: UUID?
    private var name = "Recorded Ride"
    private var createdAt: Date?
    private var updatedAt: Date?
    private var segments: [RideRouteSegment] = []
    private var activeSegmentPoints: [RideRoutePoint] = []
    private var activeStartedAt: Date?
    private var accumulatedActiveSeconds: TimeInterval = .zero
    public private(set) var phase = RouteRecordingPhase.idle

    public init() {}

    public mutating func start(at date: Date, name: String = "Recorded Ride") {
        guard phase == .idle || phase == .finished else { return }
        id = UUID()
        self.name = name
        createdAt = date
        updatedAt = date
        segments = []
        activeSegmentPoints = []
        activeStartedAt = date
        accumulatedActiveSeconds = .zero
        phase = .recording
    }

    public mutating func append(_ point: RideRoutePoint) {
        guard phase == .recording else { return }
        guard shouldAppend(point) else { return }
        activeSegmentPoints.append(point)
        if let timestamp = point.timestamp {
            updatedAt = effectiveDate(timestamp)
        }
    }

    public mutating func pause(at date: Date) {
        guard phase == .recording else { return }
        let date = effectiveDate(date)
        closeActiveSegment()
        accumulateActiveTime(at: date)
        activeStartedAt = nil
        updatedAt = date
        phase = .paused
    }

    public mutating func resume(at date: Date) {
        guard phase == .paused else { return }
        let date = effectiveDate(date)
        activeSegmentPoints = []
        activeStartedAt = date
        updatedAt = date
        phase = .recording
    }

    public mutating func finish(at date: Date) -> RideRoute? {
        guard phase == .recording || phase == .paused else { return nil }
        let date = effectiveDate(date)
        if phase == .recording {
            closeActiveSegment()
            accumulateActiveTime(at: date)
        }
        activeStartedAt = nil
        updatedAt = date
        phase = .finished
        return route
    }

    public mutating func reset() {
        self = Self()
    }

    public func snapshot(at date: Date) -> RouteRecordingSnapshot {
        .init(
            phase: phase,
            route: routeIncludingActiveSegment,
            activeElapsedSeconds: activeElapsed(at: date)
        )
    }

    private var route: RideRoute? {
        makeRoute(segments: segments)
    }

    private var routeIncludingActiveSegment: RideRoute? {
        let active = activeSegmentPoints.isEmpty
            ? segments
            : segments + [RideRouteSegment(points: activeSegmentPoints)]
        return makeRoute(segments: active)
    }

    private func makeRoute(segments: [RideRouteSegment]) -> RideRoute? {
        guard let id,
              let createdAt,
              segments.contains(where: { !$0.points.isEmpty }) else { return nil }
        return RideRoute(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            segments: segments
        )
    }

    private mutating func closeActiveSegment() {
        guard !activeSegmentPoints.isEmpty else { return }
        segments.append(RideRouteSegment(points: activeSegmentPoints))
        activeSegmentPoints = []
    }

    private mutating func accumulateActiveTime(at date: Date) {
        guard let activeStartedAt else { return }
        accumulatedActiveSeconds += max(date.timeIntervalSince(activeStartedAt), .zero)
    }

    private func activeElapsed(at date: Date) -> TimeInterval {
        guard phase == .recording, let activeStartedAt else { return accumulatedActiveSeconds }
        return accumulatedActiveSeconds + max(
            effectiveDate(date).timeIntervalSince(activeStartedAt),
            .zero
        )
    }

    private func effectiveDate(_ date: Date) -> Date {
        max(date, updatedAt ?? createdAt ?? date)
    }

    private func shouldAppend(_ point: RideRoutePoint) -> Bool {
        guard let accuracy = point.horizontalAccuracyMeters,
              accuracy.isFinite,
              accuracy >= .zero,
              accuracy <= Constants.maximumHorizontalAccuracyMeters else { return false }
        guard let previous = activeSegmentPoints.last else { return true }
        let distance = RideRouteGeometry.distanceMeters(
            from: previous.coordinate,
            to: point.coordinate
        )
        let elapsed = point.timestamp.flatMap { current in
            previous.timestamp.map { current.timeIntervalSince($0) }
        } ?? .infinity
        return distance >= Constants.minimumPointDistanceMeters
            || elapsed >= Constants.maximumPointIntervalSeconds
    }

    private enum Constants {
        static let maximumHorizontalAccuracyMeters = 50.0
        static let minimumPointDistanceMeters = 3.0
        static let maximumPointIntervalSeconds: TimeInterval = 5
    }
}
