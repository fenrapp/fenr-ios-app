import Foundation

public struct RideTrip: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let applicationSessionID: UUID
    public let startedAt: Date
    public let updatedAt: Date
    public let endedAt: Date?
    public let startingOdometerKilometers: Double?
    public let distanceKilometers: Double
    public let elapsedSeconds: TimeInterval
    public let averageSpeedKilometersPerHour: Double
    public let maximumSpeedKilometersPerHour: Double
    public let accumulatedSpeedKilometersPerHourSeconds: Double
    public let speedSampleDurationSeconds: TimeInterval
    public let lastSpeedKilometersPerHour: Double?
    public let pausedAt: Date?
    public let accumulatedPausedSeconds: TimeInterval
    public let isAwaitingOdometerRebase: Bool

    public var isPaused: Bool { pausedAt != nil }

    public init(
        id: UUID = UUID(),
        applicationSessionID: UUID,
        startedAt: Date,
        updatedAt: Date? = nil,
        endedAt: Date? = nil,
        startingOdometerKilometers: Double? = nil,
        distanceKilometers: Double = .zero,
        elapsedSeconds: TimeInterval = .zero,
        averageSpeedKilometersPerHour: Double = .zero,
        maximumSpeedKilometersPerHour: Double = .zero,
        accumulatedSpeedKilometersPerHourSeconds: Double = .zero,
        speedSampleDurationSeconds: TimeInterval = .zero,
        lastSpeedKilometersPerHour: Double? = nil,
        pausedAt: Date? = nil,
        accumulatedPausedSeconds: TimeInterval = .zero,
        isAwaitingOdometerRebase: Bool = false
    ) {
        self.id = id
        self.applicationSessionID = applicationSessionID
        self.startedAt = startedAt
        self.updatedAt = updatedAt ?? startedAt
        self.endedAt = endedAt
        self.startingOdometerKilometers = startingOdometerKilometers
        self.distanceKilometers = distanceKilometers
        self.elapsedSeconds = elapsedSeconds
        self.averageSpeedKilometersPerHour = averageSpeedKilometersPerHour
        self.maximumSpeedKilometersPerHour = maximumSpeedKilometersPerHour
        self.accumulatedSpeedKilometersPerHourSeconds = accumulatedSpeedKilometersPerHourSeconds
        self.speedSampleDurationSeconds = speedSampleDurationSeconds
        self.lastSpeedKilometersPerHour = lastSpeedKilometersPerHour
        self.pausedAt = pausedAt
        self.accumulatedPausedSeconds = accumulatedPausedSeconds
        self.isAwaitingOdometerRebase = isAwaitingOdometerRebase
    }

    public func updating(
        at date: Date,
        odometerKilometers: Double?,
        speedKilometersPerHour: Double?
    ) -> RideTrip {
        guard endedAt == nil, !isPaused else { return self }
        let effectiveDate = max(date, startedAt)
        let currentOdometer = validOdometer(odometerKilometers)
        let rebasedOdometer = rebasedStartingOdometer(from: currentOdometer)
        let didRebaseOdometer = rebasedOdometer != nil
        let startingOdometer = rebasedOdometer
            ?? startingOdometerKilometers
            ?? currentOdometer
        let observedDistance = distance(
            from: startingOdometer,
            to: currentOdometer
        )
        let updatedDistance = isAwaitingOdometerRebase
            ? distanceKilometers
            : max(distanceKilometers, observedDistance ?? .zero)
        let activeElapsed = effectiveDate.timeIntervalSince(startedAt)
            - accumulatedPausedSeconds
        let updatedElapsed = max(elapsedSeconds, activeElapsed)
        let speed = validSpeed(speedKilometersPerHour)
        let updatedMaximumSpeed = max(
            maximumSpeedKilometersPerHour,
            speed ?? .zero
        )
        let sampleDuration = max(effectiveDate.timeIntervalSince(updatedAt), .zero)
        let previousSpeed = validSpeed(lastSpeedKilometersPerHour)
        let previousSampleDuration = effectiveSpeedSampleDuration
        let previousSpeedIntegral = effectiveSpeedIntegral
        let updatedSampleDuration = previousSampleDuration
            + (previousSpeed == nil ? .zero : sampleDuration)
        let updatedSpeedIntegral = previousSpeedIntegral
            + (previousSpeed ?? .zero) * sampleDuration
        let averageSpeed = updatedSampleDuration > .zero
            ? updatedSpeedIntegral / updatedSampleDuration
            : averageSpeedKilometersPerHour

        return RideTrip(
            id: id,
            applicationSessionID: applicationSessionID,
            startedAt: startedAt,
            updatedAt: effectiveDate,
            startingOdometerKilometers: startingOdometer,
            distanceKilometers: updatedDistance,
            elapsedSeconds: updatedElapsed,
            averageSpeedKilometersPerHour: averageSpeed,
            maximumSpeedKilometersPerHour: updatedMaximumSpeed,
            accumulatedSpeedKilometersPerHourSeconds: updatedSpeedIntegral,
            speedSampleDurationSeconds: updatedSampleDuration,
            lastSpeedKilometersPerHour: speed,
            accumulatedPausedSeconds: accumulatedPausedSeconds,
            isAwaitingOdometerRebase: isAwaitingOdometerRebase && !didRebaseOdometer
        )
    }

    public func paused(at date: Date) -> RideTrip {
        guard endedAt == nil, !isPaused else { return self }
        let updated = updating(
            at: date,
            odometerKilometers: nil,
            speedKilometersPerHour: nil
        )
        return RideTrip(
            id: updated.id,
            applicationSessionID: updated.applicationSessionID,
            startedAt: updated.startedAt,
            updatedAt: updated.updatedAt,
            startingOdometerKilometers: updated.startingOdometerKilometers,
            distanceKilometers: updated.distanceKilometers,
            elapsedSeconds: updated.elapsedSeconds,
            averageSpeedKilometersPerHour: updated.averageSpeedKilometersPerHour,
            maximumSpeedKilometersPerHour: updated.maximumSpeedKilometersPerHour,
            accumulatedSpeedKilometersPerHourSeconds: updated.accumulatedSpeedKilometersPerHourSeconds,
            speedSampleDurationSeconds: updated.speedSampleDurationSeconds,
            pausedAt: updated.updatedAt,
            accumulatedPausedSeconds: updated.accumulatedPausedSeconds
        )
    }

    public func resumed(
        at date: Date,
        odometerKilometers: Double?,
        speedKilometersPerHour: Double?
    ) -> RideTrip {
        guard endedAt == nil, let pausedAt else { return self }
        let effectiveDate = max(date, pausedAt)
        let updatedPausedSeconds = accumulatedPausedSeconds
            + effectiveDate.timeIntervalSince(pausedAt)
        let currentOdometer = validOdometer(odometerKilometers)
        let rebasedOdometer = currentOdometer.flatMap { odometer in
            let candidate = odometer - distanceKilometers
            return candidate >= .zero ? candidate : nil
        }
        return RideTrip(
            id: id,
            applicationSessionID: applicationSessionID,
            startedAt: startedAt,
            updatedAt: effectiveDate,
            startingOdometerKilometers: rebasedOdometer ?? startingOdometerKilometers,
            distanceKilometers: distanceKilometers,
            elapsedSeconds: elapsedSeconds,
            averageSpeedKilometersPerHour: averageSpeedKilometersPerHour,
            maximumSpeedKilometersPerHour: maximumSpeedKilometersPerHour,
            accumulatedSpeedKilometersPerHourSeconds: accumulatedSpeedKilometersPerHourSeconds,
            speedSampleDurationSeconds: speedSampleDurationSeconds,
            lastSpeedKilometersPerHour: validSpeed(speedKilometersPerHour),
            accumulatedPausedSeconds: updatedPausedSeconds,
            isAwaitingOdometerRebase: rebasedOdometer == nil
        )
    }

    public func completed(at date: Date) -> RideTrip {
        let completionDate = max(date, updatedAt)
        let updated = isPaused
            ? self
            : updating(
                at: completionDate,
                odometerKilometers: nil,
                speedKilometersPerHour: nil
            )
        return RideTrip(
            id: updated.id,
            applicationSessionID: updated.applicationSessionID,
            startedAt: updated.startedAt,
            updatedAt: completionDate,
            endedAt: completionDate,
            startingOdometerKilometers: updated.startingOdometerKilometers,
            distanceKilometers: updated.distanceKilometers,
            elapsedSeconds: updated.elapsedSeconds,
            averageSpeedKilometersPerHour: updated.averageSpeedKilometersPerHour,
            maximumSpeedKilometersPerHour: updated.maximumSpeedKilometersPerHour,
            accumulatedSpeedKilometersPerHourSeconds: updated.accumulatedSpeedKilometersPerHourSeconds,
            speedSampleDurationSeconds: updated.speedSampleDurationSeconds,
            accumulatedPausedSeconds: updated.accumulatedPausedSeconds
        )
    }

    private func validOdometer(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= .zero else { return nil }
        return value
    }

    private func validSpeed(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= .zero else { return nil }
        return value
    }

    private func distance(from start: Double?, to current: Double?) -> Double? {
        guard let start, let current, current >= start else { return nil }
        return current - start
    }

    private func rebasedStartingOdometer(from current: Double?) -> Double? {
        guard isAwaitingOdometerRebase, let current else { return nil }
        let candidate = current - distanceKilometers
        return candidate >= .zero ? candidate : nil
    }

    private var effectiveSpeedSampleDuration: TimeInterval {
        guard speedSampleDurationSeconds == .zero,
              averageSpeedKilometersPerHour > .zero,
              elapsedSeconds > .zero else {
            return speedSampleDurationSeconds
        }
        return elapsedSeconds
    }

    private var effectiveSpeedIntegral: Double {
        guard accumulatedSpeedKilometersPerHourSeconds == .zero,
              speedSampleDurationSeconds == .zero,
              averageSpeedKilometersPerHour > .zero,
              elapsedSeconds > .zero else {
            return accumulatedSpeedKilometersPerHourSeconds
        }
        return averageSpeedKilometersPerHour * elapsedSeconds
    }
}
