import BikeDiagnostics
import MaintenanceLog
import SwiftUI
import UserNotifications

@main
struct FENRApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    private let dependencies: AppRootDependencies

    init() {
        let scheduler = SystemMaintenanceReminderScheduler(
            center: .current(),
            calendar: .autoupdatingCurrent
        )
        dependencies = ProductionAppDependencyContainerFactory.makeDefault(
            maintenanceReminderScheduler: scheduler
        ).makeRootDependencies()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
        }
    }
}
