import BikeDomain

public struct DashboardCompactSpeedVisibilityMapper: Sendable {
    public init() {}

    func isVisible(for runState: BikeRunState) -> Bool {
        switch runState {
        case .on, .crawlForward, .crawlReverse: true
        case .unknown, .off, .neutral, .charging: false
        }
    }
}
