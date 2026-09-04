import Foundation

enum AppInterfaceOrientation: Equatable {
    case portrait
    case landscape
}

struct AppPresentationPolicy {
    func orientation(for state: AppNavigationState) -> AppInterfaceOrientation {
        guard state.root == .dashboard else { return .portrait }
        if state.rideNavigationMode == .fullScreen { return .landscape }
        return state.path.isEmpty ? .landscape : .portrait
    }
}
