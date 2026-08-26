enum CurrentTripDashboardPage: Int, CaseIterable, Hashable {
    case current
    case statistics

    var accessibilityLabel: String {
        switch self {
        case .current: "Current trip"
        case .statistics: "Ride statistics"
        }
    }
}
