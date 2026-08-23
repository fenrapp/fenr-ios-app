import UIKit

@MainActor
final class InterfaceOrientationController {
    static let shared = InterfaceOrientationController()

    private var requestedOrientations: UIInterfaceOrientationMask?

    private init() {}

    func request(_ orientations: UIInterfaceOrientationMask) {
        guard requestedOrientations != orientations else { return }
        requestedOrientations = orientations

        for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes {
            let preferences = UIWindowScene.GeometryPreferences.iOS(
                interfaceOrientations: orientations
            )
            windowScene.requestGeometryUpdate(preferences) { _ in
                // The system can decline a rotation while another presentation is active.
            }
        }
    }
}
