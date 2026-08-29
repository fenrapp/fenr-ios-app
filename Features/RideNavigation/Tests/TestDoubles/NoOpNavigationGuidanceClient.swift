@testable import RideNavigation

actor NoOpNavigationGuidanceClient: NavigationGuidanceClient {
    private var announcements: [String] = []
    private var successCount = 0

    func announce(_ text: String) async {
        announcements.append(text)
    }
    func notifyWarning() async {}
    func notifySuccess() async { successCount += 1 }

    func recordedAnnouncements() -> [String] {
        announcements
    }

    func recordedSuccessCount() -> Int {
        successCount
    }
}
