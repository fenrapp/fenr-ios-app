import RideDashboard

@MainActor
struct AppRideDashboardFeatureFactory: RideDashboardFeatureBuilding {
    private let container: RideDashboardDependencyContainer
    private let dependencies: RideDashboardFeatureDependencies

    init(
        container: RideDashboardDependencyContainer,
        dependencies: RideDashboardFeatureDependencies
    ) {
        self.container = container
        self.dependencies = dependencies
    }

    func makeFeature() -> RideDashboardFeatureModel {
        container.makeFeature(dependencies: dependencies)
    }
}
