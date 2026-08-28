import Foundation

public struct RideHistoryViewState: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case loading
        case bikeUnavailable
        case empty
        case loaded
    }

    public struct Summary: Equatable, Sendable {
        public let rideCountText: String
        public let distanceText: String
        public let durationText: String

        public init(rideCountText: String, distanceText: String, durationText: String) {
            self.rideCountText = rideCountText
            self.distanceText = distanceText
            self.durationText = durationText
        }
    }

    public struct Row: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let dateText: String
        public let timeText: String
        public let distanceText: String
        public let durationText: String
        public let efficiencyText: String
        public let accessibilityLabel: String

        public init(
            id: UUID,
            dateText: String,
            timeText: String,
            distanceText: String,
            durationText: String,
            efficiencyText: String,
            accessibilityLabel: String
        ) {
            self.id = id
            self.dateText = dateText
            self.timeText = timeText
            self.distanceText = distanceText
            self.durationText = durationText
            self.efficiencyText = efficiencyText
            self.accessibilityLabel = accessibilityLabel
        }
    }

    public struct DaySection: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let rides: [Row]

        public init(id: String, title: String, rides: [Row]) {
            self.id = id
            self.title = title
            self.rides = rides
        }
    }

    public let status: Status
    public let summary: Summary?
    public let daySections: [DaySection]
    public let deletingRideIDs: Set<UUID>
    public let errorMessage: String?

    public var isDeleting: Bool { !deletingRideIDs.isEmpty }
    public var rides: [Row] { daySections.flatMap(\.rides) }

    public init(
        status: Status = .loading,
        summary: Summary? = nil,
        daySections: [DaySection] = [],
        deletingRideIDs: Set<UUID> = [],
        errorMessage: String? = nil
    ) {
        self.status = status
        self.summary = summary
        self.daySections = daySections
        self.deletingRideIDs = deletingRideIDs
        self.errorMessage = errorMessage
    }
}
