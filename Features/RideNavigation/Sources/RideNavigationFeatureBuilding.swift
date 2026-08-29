import SwiftUI

@MainActor
public protocol RideNavigationFeatureBuilding {
    func makeFeature() -> RideNavigationFeatureModel
}

@MainActor
public final class RideNavigationFeatureModel: ObservableObject {
    let viewModel: RideNavigationViewModel
    let mapSurfaceFactory: RideNavigationMapSurfaceFactory

    public init(
        viewModel: RideNavigationViewModel,
        mapSurfaceFactory: RideNavigationMapSurfaceFactory
    ) {
        self.viewModel = viewModel
        self.mapSurfaceFactory = mapSurfaceFactory
    }
}
