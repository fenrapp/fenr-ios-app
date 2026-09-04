import Foundation
import MaintenanceLog
import SwiftUI
import UserNotifications

@main
struct FENRDebugApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    private let dependencies: AppRootDependencies
    @StateObject private var scenarioController: DebugScenarioController

    init() {
        let scheduler = SystemMaintenanceReminderScheduler(
            center: .current(),
            calendar: .autoupdatingCurrent
        )
        let context = DebugAppDependencyContainerFactory.makeDefault(
            maintenanceReminderScheduler: scheduler
        )
        dependencies = context.container.makeRootDependencies(
            opensRideNavigationOnLaunch: ProcessInfo.processInfo.arguments.contains(
                "-openRideNavigation"
            )
        )
        _scenarioController = StateObject(wrappedValue: context.scenarioController)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                dependencies: dependencies,
                settingsAccessory: {
                    AnyView(DebugPowerModeControls(controller: scenarioController))
                }
            )
        }
    }
}
