enum EfficiencyDashboardPage: Int, CaseIterable, Hashable {
    case live
    case trend

    var accessibilityLabel: String {
        switch self {
        case .live: "Live efficiency"
        case .trend: "Efficiency trend"
        }
    }
}
