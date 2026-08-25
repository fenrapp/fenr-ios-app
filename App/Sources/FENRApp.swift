import BikeDiagnostics
import SwiftUI

@main
struct FENRApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    private let dependencies: AppRootDependencies

    init() {
        dependencies = ProductionAppDependencyContainerFactory.makeDefault().makeRootDependencies()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
        }
    }
}
