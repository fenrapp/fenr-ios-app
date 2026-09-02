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

    var errorDescription: String? {
        rideDashboardLocalized(.rideDashboardBikeLockErrorStopBike)
    }
}
