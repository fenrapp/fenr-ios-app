import Foundation
import SwiftData

@Model
final class MaintenanceEntryRecord {
    @Attribute(.unique) var id: UUID
    var vin: String
    var kindRawValue: String
    var customName: String?
    var matchingKey: String
    var performedAt: Date
    var odometerKilometers: Double?
    var ridingHours: Double?
    var notes: String?
    var workshop: String?
    var costMinorUnits: Int64?
    var currencyCode: String?
    var dueDate: Date?
    var dueOdometerKilometers: Double?
    var dueRidingHours: Double?
    var reminderCompletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        vin: String,
        kindRawValue: String,
        matchingKey: String,
        performedAt: Date,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.vin = vin
        self.kindRawValue = kindRawValue
        self.matchingKey = matchingKey
        self.performedAt = performedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
