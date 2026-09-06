import Foundation

public struct MaintenanceFormViewState: Equatable, Sendable {
    public struct Option: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let detail: String
        public let symbolName: String

        public init(id: String, title: String, detail: String, symbolName: String) {
            self.id = id
            self.title = title
            self.detail = detail
            self.symbolName = symbolName
        }
    }

    public struct CurrencyOption: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String

        public init(id: String, title: String) {
            self.id = id
            self.title = title
        }
    }

    public let options: [Option]
    public let currencyOptions: [CurrencyOption]
    public let distanceUnit: String

    public init(
        options: [Option],
        currencyOptions: [CurrencyOption],
        distanceUnit: String
    ) {
        self.options = options
        self.currencyOptions = currencyOptions
        self.distanceUnit = distanceUnit
    }
}

public struct MaintenanceFormDraft: Equatable, Sendable {
    public var entryID: UUID?
    public var kindID: String
    public var customName: String
    public var performedAt: Date
    public var odometerText: String
    public var ridingHoursText: String
    public var notes: String
    public var workshop: String
    public var costText: String
    public var currencyCode: String
    public let maximumPerformedAt: Date
    public var hasDateReminder: Bool
    public var dueDate: Date
    public var hasOdometerReminder: Bool
    public var dueOdometerText: String
    public var hasHoursReminder: Bool
    public var dueHoursText: String

    public init(
        entryID: UUID? = nil,
        kindID: String,
        customName: String = "",
        performedAt: Date = Date(),
        odometerText: String = "",
        ridingHoursText: String = "",
        notes: String = "",
        workshop: String = "",
        costText: String = "",
        currencyCode: String,
        maximumPerformedAt: Date,
        hasDateReminder: Bool = false,
        dueDate: Date = Date(),
        hasOdometerReminder: Bool = false,
        dueOdometerText: String = "",
        hasHoursReminder: Bool = false,
        dueHoursText: String = ""
    ) {
        self.entryID = entryID
        self.kindID = kindID
        self.customName = customName
        self.performedAt = performedAt
        self.odometerText = odometerText
        self.ridingHoursText = ridingHoursText
        self.notes = notes
        self.workshop = workshop
        self.costText = costText
        self.currencyCode = currencyCode
        self.maximumPerformedAt = maximumPerformedAt
        self.hasDateReminder = hasDateReminder
        self.dueDate = dueDate
        self.hasOdometerReminder = hasOdometerReminder
        self.dueOdometerText = dueOdometerText
        self.hasHoursReminder = hasHoursReminder
        self.dueHoursText = dueHoursText
    }
}
