import UIKit

@MainActor
protocol InterfaceOrientationControlling: AnyObject {
    func request(_ orientations: UIInterfaceOrientationMask)
}

@MainActor
final class InterfaceOrientationController: InterfaceOrientationControlling {
    static let shared = InterfaceOrientationController()

    private var adaptivePresentations: Set<UUID> = []
    private var requestedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}

    var supportedOrientations: UIInterfaceOrientationMask {
        adaptivePresentations.isEmpty ? requestedOrientations : .allButUpsideDown
    }

    func request(_ orientations: UIInterfaceOrientationMask) {
        guard requestedOrientations != orientations else { return }
        requestedOrientations = orientations
        updateScenes()
    }

    func beginAdaptivePresentation(_ id: UUID) {
        adaptivePresentations.insert(id)
        updateScenes()
    }

    func endAdaptivePresentation(_ id: UUID) {
        adaptivePresentations.remove(id)
        updateScenes()
    }

    private func updateScenes() {
        for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes {
            let orientations = adaptivePresentations.isEmpty
                ? supportedOrientations.preservingCurrentOrientation(windowScene.interfaceOrientation)
                : supportedOrientations
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: orientations)
            var controller = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
            while let current = controller {
                current.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller = current.presentedViewController
            }
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
