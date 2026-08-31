import BikeDomain

extension BikeEmulatorRepository {
    func publishDebugEvent(title: String, detail: String) async {
        let date = await runtime.now()
        await debugEventHub.send(BikeDebugEvent(date: date, title: title, detail: detail))
    }
}
