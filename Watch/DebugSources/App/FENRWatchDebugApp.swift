import SwiftUI
import WatchDashboard

@main
struct FENRWatchDebugApp: App {
    @WKApplicationDelegateAdaptor(WatchCompanionAppDelegate.self) private var appDelegate
    private let viewModel: WatchDashboardViewModel

    init() {
        if let scenario = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-debugScenario=") }) {
            viewModel = WatchAppFactory.makeViewModel(session: WatchCompanionPreviewSession(scenario: scenario))
        } else {
            viewModel = WatchAppFactory.makeViewModel()
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack { WatchDashboardView(viewModel: viewModel) }
                .transformEnvironment(\.isLuminanceReduced) { reduced in
                    if ProcessInfo.processInfo.arguments.contains("-debugLuminanceReduced") { reduced = true }
                }
        }
    }
}
