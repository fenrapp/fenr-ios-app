import SwiftUI

@main
struct FENRDebugApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    private let container: AppDependencyContainer
    @StateObject private var scenarioController: DebugScenarioController

    init() {
        let context = DebugAppDependencyContainerFactory.makeDefault()
        container = context.container
        _scenarioController = StateObject(wrappedValue: context.scenarioController)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                container: container,
                batteryHealthAccessory: {
                    AnyView(DebugScenarioPicker(controller: scenarioController))
                }
            )
        }
    }
}
