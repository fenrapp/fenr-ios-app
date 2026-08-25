import SwiftUI

@main
struct FENRWatchDebugApp: App {
    private let dependencies: WatchRootDependencies

    init() {
        dependencies = DebugWatchAppDependencyContainerFactory.makeDefault().makeRootDependencies()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(dependencies: dependencies)
        }
    }
}
