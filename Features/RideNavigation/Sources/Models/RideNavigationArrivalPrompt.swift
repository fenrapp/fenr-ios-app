import Foundation

public struct RideNavigationArrivalPrompt: Equatable, Sendable {
    public let title: String
    public let detail: String

    public init(
        title: String? = nil,
        detail: String? = nil
    ) {
        self.title = title ?? String(localized: .rideNavigationArrivalTitle)
        self.detail = detail ?? String(localized: .rideNavigationArrivalDetail)
    }
}
