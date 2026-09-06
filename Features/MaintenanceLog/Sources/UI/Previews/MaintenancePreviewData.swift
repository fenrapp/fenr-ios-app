import Foundation

#if DEBUG
enum MaintenancePreviewData {
    static let entryID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let row = MaintenanceLogViewState.Row(
        id: entryID,
        symbolName: "drop.fill",
        title: String(localized: .maintenanceKindGearOil),
        dateText: "Sep 6, 2026",
        detailText: "1,250 km",
        reminderText: "Next service: 1,500 km"
    )
    static let list = MaintenanceLogViewState(status: .loaded, due: [row], history: [row])
    static let detail = MaintenanceDetailViewState(
        id: entryID,
        title: row.title,
        symbolName: row.symbolName,
        fields: [
            .init(id: "date", label: String(localized: .maintenanceFieldDate), value: row.dateText),
            .init(id: "odometer", label: String(localized: .maintenanceFieldOdometer), value: "1,250 km"),
            .init(
                id: "notes",
                label: String(localized: .maintenanceFieldNotes),
                value: "Oil changed after a muddy ride."
            )
        ],
        reminderFields: [.init(id: "due", label: String(localized: .maintenanceDueOdometer), value: "1,500 km")],
        officialGuidance: nil
    )
    static let types: [MaintenanceFormViewState.Option] = [
        .init(
            id: "gearOil",
            title: String(localized: .maintenanceKindGearOil),
            detail: String(localized: .maintenanceDescriptionGearOil),
            symbolName: "drop.fill"
        ),
        .init(
            id: "generalInspection",
            title: String(localized: .maintenanceKindGeneralInspection),
            detail: String(localized: .maintenanceDescriptionGeneralInspection),
            symbolName: "checkmark.seal.fill"
        )
    ]
}
#endif
