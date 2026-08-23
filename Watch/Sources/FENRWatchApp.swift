import SwiftUI

@main
struct FENRWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView(container: .makeLive())
        }
    }
}
