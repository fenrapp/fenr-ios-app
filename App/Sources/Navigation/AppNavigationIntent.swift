import Foundation

enum AppNavigationIntent: Equatable {
    case push(AppRoute)
    case replacePath([AppRoute])
    case pop(ifTop: AppRoute?)
    case popToRoot
    case showRideNavigation(AppExternalNavigationRequest?)
    case minimizeRideNavigation
    case expandRideNavigation
    case closeRideNavigation
    case setRoot(AppNavigationRoot)
    case resetSetup
}
