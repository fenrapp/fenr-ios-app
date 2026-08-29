import Foundation

actor BikeIMUSampleRateLimiter {
    private let minimumInterval: TimeInterval
    private var lastAcceptedDate: Date?

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = max(minimumInterval, .zero)
    }

    func shouldAccept(_ date: Date) -> Bool {
        guard let lastAcceptedDate else {
            self.lastAcceptedDate = date
            return true
        }
        let interval = date.timeIntervalSince(lastAcceptedDate)
        if interval < .zero {
            self.lastAcceptedDate = date
            return true
        }
        guard interval + Constants.comparisonTolerance >= minimumInterval else { return false }
        self.lastAcceptedDate = date
        return true
    }

    func reset() {
        lastAcceptedDate = nil
    }

    private enum Constants {
        static let comparisonTolerance: TimeInterval = 1e-9
    }
}
