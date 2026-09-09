import AsyncSupport
import BikeDomain

public struct BikePowerModeCurveConfirmationCoordinator: Sendable {
    private let stateStore: BikeRepositoryStateStore
    private let telemetryHub: AsyncEventHub<BikeTelemetry>

    public init(stateStore: BikeRepositoryStateStore, telemetryHub: AsyncEventHub<BikeTelemetry>) {
        self.stateStore = stateStore
        self.telemetryHub = telemetryHub
    }

    func perform(
        mapIndex: Int, advancedEditBaseline: BikeAdvancedPowerModeConfiguration? = nil,
        operation: @Sendable () async throws -> BikeAdvancedPowerModeConfiguration
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        let context = await stateStore.curveReadContext(mapIndex: mapIndex)
        do {
            let value = try await operation()
            try Task.checkCancellation()
            if let telemetry = await stateStore.confirmCurves(
                value, context: context, advancedEditBaseline: advancedEditBaseline
            ) {
                await telemetryHub.send(telemetry)
            }
            return value
        } catch {
            if let telemetry = await stateStore.confirmCurves(nil, context: context) {
                await telemetryHub.send(telemetry)
            }
            throw error
        }
    }
}
