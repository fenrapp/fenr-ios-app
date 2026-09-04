import Foundation

public struct MaintenanceDetailViewState: Equatable, Sendable {
    public struct Field: Equatable, Identifiable, Sendable {
        public let id: String
        public let label: String
        public let value: String

        public init(id: String, label: String, value: String) {
            self.id = id
            self.label = label
            self.value = value
        }
    }

    public let id: UUID
    public let title: String
    public let symbolName: String
    public let fields: [Field]
    public let reminderFields: [Field]
    public let officialGuidance: String?

    public init(
        id: UUID,
        title: String,
        symbolName: String,
        fields: [Field],
        reminderFields: [Field],
        officialGuidance: String?
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.fields = fields
        self.reminderFields = reminderFields
        self.officialGuidance = officialGuidance
    }
}
