public enum DashboardCardSettingsDestination: Hashable, Sendable {
    case overview
    case section(id: String)
}

public enum DashboardCardSettingsNavigationEvent: Equatable, Sendable {
    case show(DashboardCardSettingsDestination)
}
