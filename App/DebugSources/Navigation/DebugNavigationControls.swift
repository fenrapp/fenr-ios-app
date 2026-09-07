import Observation

@MainActor
@Observable
final class DebugNavigationControls {
    private let source: DebugNavigationLocationSource
    private let fault: DebugNavigationSaveFault
    private(set) var saveFailureRequests = 0
    var emittedSampleCount: Int { source.emittedSampleCount }

    init(source: DebugNavigationLocationSource, fault: DebugNavigationSaveFault) {
        self.source = source
        self.fault = fault
    }

    func advanceGPS() { source.advance() }

    func failNextRouteSave() {
        fault.arm()
        saveFailureRequests += 1
    }
}
