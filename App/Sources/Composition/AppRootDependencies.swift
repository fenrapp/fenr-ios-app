@MainActor
struct AppRootDependencies {
    let featureStore: AppFeatureStore
    let setupFlow: BikeSetupFlowController
    let navigationCoordinator: AppNavigationCoordinator
    let incomingMapLinkController: IncomingMapLinkController
    let externalNavigationResolver: AppExternalNavigationResolver
    let presentationController: AppPresentationController
    let lifecycleController: AppLifecycleController
}
