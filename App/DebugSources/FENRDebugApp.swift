import SwiftUI

@main
struct FENRDebugApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    private let dependencies: AppRootDependencies
    @StateObject private var scenarioController: DebugScenarioController

    init() {
        let context = DebugAppDependencyContainerFactory.makeDefault()
        dependencies = context.container.makeRootDependencies()
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
