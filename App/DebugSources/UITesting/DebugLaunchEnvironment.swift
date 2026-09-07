import Foundation

@MainActor
struct DebugLaunchEnvironment {
    let defaults: UserDefaults
    let uiTestSession: DebugUITestSession?
    let profileStore: DebugUITestProfileStore?
    let controls: DebugUITestControls?
    let navigation: DebugNavigationHarness?
    let forceOnboarding: Bool
}
