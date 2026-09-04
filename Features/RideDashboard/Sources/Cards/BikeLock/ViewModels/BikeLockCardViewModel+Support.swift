import Foundation

enum BikeLockSheetUpdate {
    case preserve
    case present(BikeLockCardViewState.Sheet)
    case dismiss

    func resolve(current: BikeLockCardViewState.Sheet?) -> BikeLockCardViewState.Sheet? {
        switch self {
        case .preserve:
            current
        case let .present(sheet):
            sheet
        case .dismiss:
            nil
        }
    }
}

enum BikeLockCardOperationError: LocalizedError {
    case vehicleMustBeStationary
    case noOpValidationFailed

    var errorDescription: String? {
        switch self {
        case .vehicleMustBeStationary:
            rideDashboardLocalized(.rideDashboardBikeLockErrorStopBike)
        case .noOpValidationFailed:
            rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed)
        }
    }
}
