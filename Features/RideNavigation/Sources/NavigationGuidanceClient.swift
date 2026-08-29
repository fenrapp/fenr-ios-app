public protocol NavigationGuidanceClient: Sendable {
    func announce(_ text: String) async
    func notifyWarning() async
    func notifySuccess() async
}
