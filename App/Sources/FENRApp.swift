import SwiftUI

@main
struct FENRApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    @State private var experienceController: AppExperienceController?

    var body: some Scene {
        WindowGroup {
            Group {
                if let experienceController {
                    AppExperienceView(controller: experienceController)
                } else {
                    ProgressView()
                }
            }
            .task {
                guard !Task.isCancelled, experienceController == nil else { return }
                experienceController = AppExperienceFactory.makeController()
            }
        }
    }
}
