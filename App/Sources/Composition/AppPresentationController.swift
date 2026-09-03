import UIKit

@MainActor
final class AppPresentationController {
    private let policy: AppPresentationPolicy
    private let orientationController: any InterfaceOrientationControlling
    private var lastOrientation: AppInterfaceOrientation?

    init(
        policy: AppPresentationPolicy,
        orientationController: any InterfaceOrientationControlling
    ) {
        self.policy = policy
        self.orientationController = orientationController
    }

    func update(for state: AppNavigationState) {
        let orientation = policy.orientation(for: state)
        guard orientation != lastOrientation else { return }
        lastOrientation = orientation
        orientationController.request(orientation.interfaceOrientationMask)
    }
}

private extension AppInterfaceOrientation {
    var interfaceOrientationMask: UIInterfaceOrientationMask {
        switch self {
        case .portrait: .portrait
        case .landscape: .landscape
        }
    }
}
