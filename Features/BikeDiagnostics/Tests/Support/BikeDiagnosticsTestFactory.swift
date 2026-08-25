import BikeDiagnostics
import BikeDomain
import Foundation
import MeasurementPresentation

@MainActor
func makeViewModel(
    repository: FakeBikeDiagnosticsRepository,
    profileRepository: any BikeProfileRepository = FakeBikeProfileRepository()
) -> BikeDiagnosticsViewModel {
    let pinDeriver = FakeBikePinDeriver()
    return BikeDiagnosticsViewModel(
        useCases: BikeDiagnosticsUseCases(
            start: .init(repository: repository),
            stop: .init(repository: repository),
            connect: .init(repository: repository),
            disconnect: .init(repository: repository),
            retrySecurityHandshake: .init(repository: repository),
            readTelemetrySnapshot: .init(repository: repository),
            observeTelemetry: .init(repository: repository),
            observeConnection: .init(repository: repository),
            observeDebugEvents: .init(repository: repository),
            derivePin: .init(pinDeriver: pinDeriver),
            loadProfile: .init(repository: profileRepository),
            observeSettings: .init(repository: FakeAppSettingsRepository())
        ),
        mappers: makeMappers(),
        makeMappers: { _ in makeMappers() }
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
            badgesMapper: .init(runStateMapper: .init()),
            rawFlagsMapper: .init(),
            debugEventMapper: .init(dateFormatStyle: dateFormatStyle)
        )
    )
}
