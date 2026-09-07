import RideNavigation

struct DebugNavigationGuidanceClient: NavigationGuidanceClient {
    func announce(_ text: String) async {}
    func notifyWarning() async {}
    func notifySuccess() async {}
}
