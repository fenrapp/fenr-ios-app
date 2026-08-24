import BikeDiagnostics
import SwiftUI

@main
struct FENRApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    private let container: AppDependencyContainer

    init() {
        container = ProductionAppDependencyContainerFactory.makeDefault()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container)
        }
    }
}
