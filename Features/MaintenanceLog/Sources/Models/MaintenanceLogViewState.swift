import Foundation

public struct MaintenanceLogViewState: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case bikeUnavailable
        case failed
        case loading
        case loaded
    }

    public struct Row: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let symbolName: String
        public let title: String
        public let dateText: String
        public let detailText: String?
        public let reminderText: String?

        public init(
            id: UUID,
            symbolName: String,
            title: String,
            dateText: String,
            detailText: String? = nil,
            reminderText: String? = nil
        ) {
            self.id = id
            self.symbolName = symbolName
            self.title = title
            self.dateText = dateText
            self.detailText = detailText
            self.reminderText = reminderText
        }
    }

    public let status: Status
    public let due: [Row]
    public let upcoming: [Row]
    public let history: [Row]
    public let errorMessage: String?
    public let loadErrorMessage: String?

    public init(
        status: Status = .bikeUnavailable,
        due: [Row] = [],
        upcoming: [Row] = [],
        history: [Row] = [],
        errorMessage: String? = nil,
        loadErrorMessage: String? = nil
    ) {
        self.status = status
        self.due = due
        self.upcoming = upcoming
        self.history = history
        self.errorMessage = errorMessage
        self.loadErrorMessage = loadErrorMessage
    }
}
