import SwiftUI
import WatchDashboard

@main
struct FENRWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchCompanionAppDelegate.self) private var appDelegate
    private let viewModel = WatchAppFactory.makeViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack { WatchDashboardView(viewModel: viewModel) }
        }
    }
}
