import BikeDomain

extension BikeEmulatorRepository {
    func publishDebugEvent(title: String, detail: String) async {
        await debugEventHub.send(BikeDebugEvent(title: title, detail: detail))
    }
}
