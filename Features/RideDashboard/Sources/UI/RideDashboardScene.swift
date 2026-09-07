import SwiftUI

@MainActor
public struct RideDashboardScene: View {
    @State private var feature: RideDashboardFeatureModel?
    private let factory: any RideDashboardFeatureBuilding
    private let onNavigation: (RideDashboardNavigationEvent) -> Void
    private let onRetryConnection: () -> Void
    private let isNavigationActive: Bool
    private let isPresentationActive: Bool
    private let bottomLeadingAccessory: () -> AnyView

    public init(
        factory: any RideDashboardFeatureBuilding,
        onNavigation: @escaping (RideDashboardNavigationEvent) -> Void,
        onRetryConnection: @escaping () -> Void,
        isNavigationActive: Bool = false,
        isPresentationActive: Bool = true,
        bottomLeadingAccessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        self.factory = factory
        self.onNavigation = onNavigation
        self.onRetryConnection = onRetryConnection
        self.isNavigationActive = isNavigationActive
        self.isPresentationActive = isPresentationActive
        self.bottomLeadingAccessory = bottomLeadingAccessory
    }

    public var body: some View {
        Group {
            if let feature {
                RideDashboardView(
                    feature: feature,
                    onSettings: { onNavigation(.openSettings) },
                    onNavigation: { onNavigation(.openRideNavigation) },
                    isNavigationActive: isNavigationActive,
                    isPresentationActive: isPresentationActive,
                    onRetryConnection: onRetryConnection,
                    bottomLeadingAccessory: bottomLeadingAccessory
                )
            } else {
                ProgressView()
            }
        }
        .task {
            guard !Task.isCancelled else { return }
            if feature == nil { feature = factory.makeFeature() }
        }
    }
}
