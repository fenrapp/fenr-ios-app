import SettingsDomain

@MainActor
final class DemoCredentialServiceRecorder {
    private(set) var requestedServices: [String] = []

    func makeStore(service: String) -> any BikeLockCredentialStoring {
        requestedServices.append(service)
        return DemoTestCredentialStore()
    }
}
