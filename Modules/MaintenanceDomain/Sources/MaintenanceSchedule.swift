import Foundation

public struct MaintenanceSchedule: Equatable, Codable, Sendable {
    public var dueDate: Date?
    public var dueOdometerKilometers: Double?
    public var dueRidingHours: Double?
    public var completedAt: Date?

    public init(
        dueDate: Date? = nil,
        dueOdometerKilometers: Double? = nil,
        dueRidingHours: Double? = nil,
        completedAt: Date? = nil
    ) {
        self.dueDate = dueDate
        self.dueOdometerKilometers = dueOdometerKilometers
        self.dueRidingHours = dueRidingHours
        self.completedAt = completedAt
    }

    public var hasDueValue: Bool {
        dueDate != nil || dueOdometerKilometers != nil || dueRidingHours != nil
    }

    public func status(
        now: Date,
        odometerKilometers: Double?,
        ridingHours: Double?
    ) -> MaintenanceDueStatus {
        if completedAt != nil { return .completed }
        let isDue = dueDate.map { $0 <= now } == true
            || dueOdometerKilometers.map { due in odometerKilometers.map { $0 >= due } == true } == true
            || dueRidingHours.map { due in ridingHours.map { $0 >= due } == true } == true
        return isDue ? .due : .upcoming
    }
}

public enum MaintenanceDueStatus: Equatable, Sendable {
    case due
    case upcoming
    case completed
}

public struct MaintenanceRecommendation: Equatable, Sendable {
    public let ridingHourInterval: Double?
    public let monthInterval: Int?
    public let oneTimeRidingHours: Double?

    public init(
        ridingHourInterval: Double? = nil,
        monthInterval: Int? = nil,
        oneTimeRidingHours: Double? = nil
    ) {
        self.ridingHourInterval = ridingHourInterval
        self.monthInterval = monthInterval
        self.oneTimeRidingHours = oneTimeRidingHours
    }
}

public enum MaintenanceCatalog {
    public static func recommendation(for kind: MaintenanceKind) -> MaintenanceRecommendation? {
        switch kind {
        case .breakInGearOil:
            .init(oneTimeRidingHours: 5)
        case .brakeFluid:
            .init(monthInterval: 12)
        case .forkOil:
            .init(ridingHourInterval: 15, monthInterval: 12)
        case .forkService:
            .init(ridingHourInterval: 40, monthInterval: 12)
        case .motorGearInspection:
            .init(ridingHourInterval: 80, monthInterval: 12)
        default:
            nil
        }
    }

    public static func suggestedSchedule(
        after date: Date,
        ridingHours: Double?,
        for kind: MaintenanceKind,
        calendar: Calendar = .autoupdatingCurrent
    ) -> MaintenanceSchedule? {
        guard let recommendation = recommendation(for: kind), recommendation.oneTimeRidingHours == nil else {
            return nil
        }
        let dueDate = recommendation.monthInterval.flatMap {
            calendar.date(byAdding: .month, value: $0, to: date)
        }
        let dueHours = recommendation.ridingHourInterval.flatMap { interval in
            ridingHours.map { $0 + interval }
        }
        let schedule = MaintenanceSchedule(dueDate: dueDate, dueRidingHours: dueHours)
        return schedule.hasDueValue ? schedule : nil
    }
}
