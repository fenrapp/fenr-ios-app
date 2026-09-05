import BikeDiagnostics
import BikeDomain
import BLETraceDomain
import Foundation
import MeasurementPresentation

@MainActor
func makeViewModel(
    repository: FakeBikeDiagnosticsRepository,
    session: FakeVehicleSession = FakeVehicleSession(),
    traceRepository: any BLETraceLogRepository = NoOpBLETraceRepository(),
    bleTraceCaptureConfirmationTimeout: Duration = .milliseconds(100)
) -> BikeDiagnosticsViewModel {
    BikeDiagnosticsViewModel(
        useCases: BikeDiagnosticsUseCases(
            session: session,
            connect: .init(repository: repository),
            disconnect: .init(repository: repository),
            retrySecurityHandshake: .init(repository: repository),
            startNewDiagnosticsCapture: .init(repository: repository),
            stopDiagnosticsCapture: .init(repository: repository),
            observeDebugEvents: .init(repository: repository),
            observeBLETraceSessions: .init(repository: traceRepository),
            observeBLETraceRecordingFailures: .init(repository: traceRepository),
            prepareBLETraceExport: .init(repository: traceRepository),
            deleteBLETraceSession: .init(repository: traceRepository),
            deleteAllBLETraceSessions: .init(repository: traceRepository)
        ),
        mappers: makeMappers(),
        makeMappers: { _ in makeMappers() },
        bleTraceCaptureConfirmationTimeout: bleTraceCaptureConfirmationTimeout
    )
}

@MainActor
func makeMappers() -> BikeDiagnosticsMappers {
    let dateFormatStyle = Date.FormatStyle()
        .hour(.twoDigits(amPM: .omitted))
        .minute(.twoDigits)
        .second(.twoDigits)
    let locale = Locale(identifier: "es_ES")
    let speedFormatter = BikeDiagnosticsSpeedFormatter(
        measurementMapper: VehicleMeasurementMapper(measurementSystem: locale.measurementSystem),
        textFormatter: VehicleMeasurementTextFormatter(locale: locale)
    )
    return BikeDiagnosticsMappers(
        viewState: .init(
            connectionMapper: .init(stateMapper: .init()),
            metricsMapper: .init(
                dateFormatStyle: dateFormatStyle,
                speedFormatter: speedFormatter,
                measurementTextFormatter: .init(locale: locale)
            ),
            powerMetricsMapper: .init(
                dateFormatStyle: dateFormatStyle,
                measurementTextFormatter: .init(locale: locale)
            ),
            batteryMetricsMapper: .init(
                dateFormatStyle: dateFormatStyle,
                measurementTextFormatter: .init(locale: locale)
            ),
            badgesMapper: .init(runStateMapper: .init()),
            rawFlagsMapper: .init(),
            debugEventMapper: .init(dateFormatStyle: dateFormatStyle),
            speedFormatter: speedFormatter
        ),
        bleTraceSession: .init(
            dateFormatStyle: Date.FormatStyle(date: .abbreviated, time: .standard),
            byteCountFormatStyle: ByteCountFormatStyle(style: .file)
        ),
        bleTraceFailure: BLETraceFailureViewDataMapper()
    )
}
