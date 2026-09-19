import SwiftUI

@MainActor
public protocol RideNavigationFeatureBuilding {
    func makeFeature() -> RideNavigationFeatureModel
}

@MainActor
public struct RideNavigationFeatureModel {
    let viewModel: RideNavigationViewModel
    let mapSurfaceFactory: RideNavigationMapSurfaceFactory
    let offlineMapsFactory: OfflineMapsFeatureFactory?

    public init(
        viewModel: RideNavigationViewModel,
        mapSurfaceFactory: RideNavigationMapSurfaceFactory,
        offlineMapsFactory: OfflineMapsFeatureFactory? = nil
    ) {
        self.offlineMapsFactory = offlineMapsFactory
        self.viewModel = viewModel
        self.mapSurfaceFactory = mapSurfaceFactory
    }
}
