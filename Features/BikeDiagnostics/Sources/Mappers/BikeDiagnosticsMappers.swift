@MainActor
public struct BikeDiagnosticsMappers {
    let viewState: BikeTelemetryToBikeDiagnosticsViewStateMapper

    public init(viewState: BikeTelemetryToBikeDiagnosticsViewStateMapper) {
        self.viewState = viewState
    }
}
