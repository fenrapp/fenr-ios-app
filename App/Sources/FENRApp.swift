import BikeDiagnostics
import SwiftUI

@main
struct FENRApp: App {
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
