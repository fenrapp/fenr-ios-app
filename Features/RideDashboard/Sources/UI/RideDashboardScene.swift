import SwiftUI

@MainActor
public struct RideDashboardScene: View {
    @StateObject private var feature: RideDashboardFeatureModel
    private let onSettings: () -> Void
    private let onDiagnostics: () -> Void
    private let onNavigation: () -> Void
    private let isNavigationActive: Bool
    private let isPresentationActive: Bool

    public init(
        factory: any RideDashboardFeatureBuilding,
        onSettings: @escaping () -> Void = {},
        onNavigation: @escaping () -> Void = {},
        isNavigationActive: Bool = false,
        isPresentationActive: Bool = true,
        onDiagnostics: @escaping () -> Void
    ) {
        _feature = StateObject(wrappedValue: factory.makeFeature())
        self.onSettings = onSettings
        self.onNavigation = onNavigation
        self.isNavigationActive = isNavigationActive
        self.isPresentationActive = isPresentationActive
        self.onDiagnostics = onDiagnostics
    }

    public var body: some View {
        RideDashboardView(
            feature: feature,
            onSettings: onSettings,
            onNavigation: onNavigation,
            isNavigationActive: isNavigationActive,
            isPresentationActive: isPresentationActive,
            onDiagnostics: onDiagnostics
        )
    }
}
