import Foundation
import MaintenanceLog
import SwiftUI
import UserNotifications

@main
struct FENRDebugApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    private let dependencies: AppRootDependencies
    private let uiTestControls: DebugUITestControls?
    private let navigationControls: DebugNavigationControls?
    @State private var showsUITestControls = false
    @State private var scenarioController: DebugScenarioController

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
        _scenarioController = State(initialValue: context.scenarioController)
        uiTestControls = context.uiTestControls
        navigationControls = context.navigationControls
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                dependencies: dependencies,
                settingsAccessory: {
                    AnyView(DebugPowerModeControls(controller: scenarioController))
                }
            )
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                if uiTestControls != nil {
                    Button(.uiTestingControls) { showsUITestControls = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("uiTesting.controls")
                }
            }
            .sheet(isPresented: $showsUITestControls) {
                if let uiTestControls {
                    DebugUITestPanel(controls: uiTestControls, navigation: navigationControls) {
                        showsUITestControls = false
                    }
                }
            }
        }
    }
}
