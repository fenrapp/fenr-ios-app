import UIKit

@MainActor
protocol InterfaceOrientationControlling: AnyObject {
    func request(_ orientations: UIInterfaceOrientationMask)
}

@MainActor
final class InterfaceOrientationController: InterfaceOrientationControlling {
    static let shared = InterfaceOrientationController()

    private var requestedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}

    var supportedOrientations: UIInterfaceOrientationMask {
        requestedOrientations
    }

    func request(_ orientations: UIInterfaceOrientationMask) {
        guard requestedOrientations != orientations else { return }
        requestedOrientations = orientations

        for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes {
            let preferences = UIWindowScene.GeometryPreferences.iOS(
                interfaceOrientations: orientations.preservingCurrentOrientation(windowScene.interfaceOrientation)
            )
            windowScene.windows
                .first(where: \.isKeyWindow)?
                .rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(preferences)
        }
    }
}

extension UIInterfaceOrientationMask {
    func preservingCurrentOrientation(_ orientation: UIInterfaceOrientation) -> Self {
        let current: Self
        switch orientation {
        case .portrait: current = .portrait
        case .portraitUpsideDown: current = .portraitUpsideDown
        case .landscapeLeft: current = .landscapeLeft
        case .landscapeRight: current = .landscapeRight
        default: return self
        }
        return contains(current) ? current : self
    }
}

final class AppOrientationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        InterfaceOrientationController.shared.supportedOrientations
    }
}
