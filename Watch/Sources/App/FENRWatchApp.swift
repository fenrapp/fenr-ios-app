import SwiftUI

@main
struct FENRWatchApp: App {
    private let dependencies: WatchRootDependencies

    init() {
        dependencies = LiveWatchAppDependencyContainerFactory.makeDefault().makeRootDependencies()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(dependencies: dependencies)
        }
    }
}
