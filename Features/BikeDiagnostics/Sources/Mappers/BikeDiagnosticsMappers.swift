@MainActor
public struct BikeDiagnosticsMappers {
    let viewState: BikeTelemetryToBikeDiagnosticsViewStateMapper
    let bleTraceSession: BLETraceSessionViewDataMapper
    let bleTraceFailure: BLETraceFailureViewDataMapper

    public init(
        viewState: BikeTelemetryToBikeDiagnosticsViewStateMapper,
        bleTraceSession: BLETraceSessionViewDataMapper,
        bleTraceFailure: BLETraceFailureViewDataMapper
    ) {
        self.viewState = viewState
        self.bleTraceSession = bleTraceSession
        self.bleTraceFailure = bleTraceFailure
    }
}
