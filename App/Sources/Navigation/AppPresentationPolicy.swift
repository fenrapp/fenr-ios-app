import Foundation

enum AppInterfaceOrientation: Equatable {
    case portrait
    case landscape
    case adaptive
}

struct AppPresentationPolicy {
    func orientation(for state: AppNavigationState) -> AppInterfaceOrientation {
        guard state.root == .dashboard else { return .portrait }
        if state.rideNavigationMode == .fullScreen { return .landscape }
        if state.path.last == .advancedPowerModes { return .adaptive }
        return state.path.isEmpty ? .landscape : .portrait
    }
}
