import SwiftUI

@MainActor
public struct RideDashboardScene: View {
    @StateObject private var feature: RideDashboardFeatureModel
    private let onNavigation: (RideDashboardNavigationEvent) -> Void
    private let onRetryConnection: () -> Void
    private let isNavigationActive: Bool
    private let isPresentationActive: Bool

    public init(
        factory: any RideDashboardFeatureBuilding,
        onNavigation: @escaping (RideDashboardNavigationEvent) -> Void,
        onRetryConnection: @escaping () -> Void,
        isNavigationActive: Bool = false,
        isPresentationActive: Bool = true
    ) {
        _feature = StateObject(wrappedValue: factory.makeFeature())
        self.onNavigation = onNavigation
        self.onRetryConnection = onRetryConnection
        self.isNavigationActive = isNavigationActive
        self.isPresentationActive = isPresentationActive
    }

    public var body: some View {
        RideDashboardView(
            feature: feature,
            onSettings: { onNavigation(.openSettings) },
            onNavigation: { onNavigation(.openRideNavigation) },
            isNavigationActive: isNavigationActive,
            isPresentationActive: isPresentationActive,
            onRetryConnection: onRetryConnection
        )
    }
}
