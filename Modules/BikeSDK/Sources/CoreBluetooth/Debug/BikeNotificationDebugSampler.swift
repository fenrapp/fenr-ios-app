import Foundation

@MainActor
public final class BikeNotificationDebugSampler {
    private let minimumInterval: TimeInterval
    private var lastEmissionDates: [UUID: Date] = [:]

    public init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    public func shouldEmit(characteristic: UUID, date: Date) -> Bool {
        guard let lastEmissionDate = lastEmissionDates[characteristic] else {
            lastEmissionDates[characteristic] = date
            return true
        }
        guard date.timeIntervalSince(lastEmissionDate) >= minimumInterval else {
            return false
        }
        lastEmissionDates[characteristic] = date
        return true
    }

    public func reset() {
        lastEmissionDates.removeAll()
    }
}
