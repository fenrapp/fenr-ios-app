import SwiftUI

@main
struct FENRApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    @StateObject private var experienceController = AppExperienceFactory.makeController()

    var body: some Scene {
        WindowGroup {
            AppExperienceView(controller: experienceController)
        }
    }
}
