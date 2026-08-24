import UIKit

@MainActor
final class InterfaceOrientationController {
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
                interfaceOrientations: orientations
            )
            windowScene.requestGeometryUpdate(preferences)
        }
        UIViewController.attemptRotationToDeviceOrientation()
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
