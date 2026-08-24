import SwiftUI

@main
struct FENRWatchDebugApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView(container: DebugWatchAppDependencyContainerFactory.makeDefault())
        }
    }
}
