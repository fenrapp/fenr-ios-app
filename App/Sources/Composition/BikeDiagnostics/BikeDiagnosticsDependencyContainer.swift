import BikeDiagnostics
import BikeDomain
import BLETraceDomain
import Foundation
import MeasurementPresentation
import SettingsDomain
import VehicleSession

@MainActor
struct BikeDiagnosticsDependencyContainer {
    func makeBikeDiagnosticsViewModel(
        repository: BikeRepository,
        vehicleSession: any VehicleSessionService,
        bleTraceLogRepository: any BLETraceLogRepository
    ) -> BikeDiagnosticsViewModel {
        BikeDiagnosticsViewModel(
            useCases: makeUseCases(
                repository: repository,
                vehicleSession: vehicleSession,
                bleTraceLogRepository: bleTraceLogRepository
            ),
            mappers: makeMappers(measurementSystem: .system),
            makeMappers: makeMappers,
            bleTraceCaptureConfirmationTimeout: .seconds(3)
        )
    }

    private func makeUseCases(
        repository: BikeRepository,
        vehicleSession: any VehicleSessionService,
        bleTraceLogRepository: any BLETraceLogRepository
    ) -> BikeDiagnosticsUseCases {
        BikeDiagnosticsUseCases(
            session: vehicleSession,
            connect: ConnectToBikeUseCase(repository: repository),
            disconnect: DisconnectBikeUseCase(repository: repository),
            retrySecurityHandshake: RetryBikeSecurityHandshakeUseCase(repository: repository),
            startNewDiagnosticsCapture: StartNewBikeDiagnosticsCaptureUseCase(repository: repository),
            stopDiagnosticsCapture: StopBikeDiagnosticsCaptureUseCase(repository: repository),
            observeDebugEvents: ObserveBikeDebugEventsUseCase(repository: repository),
            observeBLETraceSessions: ObserveBLETraceSessionsUseCase(repository: bleTraceLogRepository),
            prepareBLETraceExport: PrepareBLETraceExportUseCase(repository: bleTraceLogRepository),
            deleteBLETraceSession: DeleteBLETraceSessionUseCase(repository: bleTraceLogRepository),
            deleteAllBLETraceSessions: DeleteAllBLETraceSessionsUseCase(repository: bleTraceLogRepository)
        )
    }

    private func makeMappers(measurementSystem: MeasurementSystem) -> BikeDiagnosticsMappers {
        let dateFormatStyle = Date.FormatStyle()
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .second(.twoDigits)
        let locale = Locale.autoupdatingCurrent
        let speedFormatter = BikeDiagnosticsSpeedFormatter(
            measurementMapper: VehicleMeasurementMapper(
                measurementSystem: measurementSystem.resolved(for: locale)
            ),
            textFormatter: VehicleMeasurementTextFormatter(locale: locale)
        )
        return BikeDiagnosticsMappers(
            viewState: BikeTelemetryToBikeDiagnosticsViewStateMapper(
                connectionMapper: BikeConnectionToConnectionPanelMapper(
                    stateMapper: ConnectionStateToDisplayMapper()
                ),
                metricsMapper: BikeTelemetryToMetricsMapper(
                    dateFormatStyle: dateFormatStyle,
                    speedFormatter: speedFormatter,
                    measurementTextFormatter: VehicleMeasurementTextFormatter(locale: locale)
                ),
                powerMetricsMapper: BikePowerTelemetryToMetricsMapper(
                    dateFormatStyle: dateFormatStyle,
                    measurementTextFormatter: VehicleMeasurementTextFormatter(locale: locale)
                ),
                batteryMetricsMapper: BikeBatteryTelemetryToMetricsMapper(
                    dateFormatStyle: dateFormatStyle,
                    measurementTextFormatter: VehicleMeasurementTextFormatter(locale: locale)
                ),
                badgesMapper: BikeTelemetryToBadgesMapper(
                    runStateMapper: BikeRunStateToBadgeMapper()
                ),
                rawFlagsMapper: BikeTelemetryToRawFlagsMapper(),
                debugEventMapper: BikeDebugEventToDebugEventViewDataMapper(
                    dateFormatStyle: dateFormatStyle
                ),
                speedFormatter: speedFormatter
            ),
            bleTraceSession: BLETraceSessionViewDataMapper(
                dateFormatStyle: Date.FormatStyle(date: .abbreviated, time: .standard),
                byteCountFormatStyle: ByteCountFormatStyle(style: .file)
            )
        )
    }

}
