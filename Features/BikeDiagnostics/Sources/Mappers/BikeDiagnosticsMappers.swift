@MainActor
public struct BikeDiagnosticsMappers {
    let viewState: BikeTelemetryToBikeDiagnosticsViewStateMapper
    let bleTraceSession: BLETraceSessionViewDataMapper

    public init(
        viewState: BikeTelemetryToBikeDiagnosticsViewStateMapper,
        bleTraceSession: BLETraceSessionViewDataMapper
    ) {
        self.viewState = viewState
        self.bleTraceSession = bleTraceSession
    }
}
