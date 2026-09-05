import BikeDomain

extension BikeEmulatorRepository {
    func publishDebugEvent(title: @autoclosure () -> String, detail: @autoclosure () -> String) async {
        guard diagnostics.captureState.isRecording else { return }
        let date = await runtime.now()
        guard diagnostics.captureState.isRecording else { return }
        await debugEventHub.send(BikeDebugEvent(date: date, title: title(), detail: detail()))
    }
}
