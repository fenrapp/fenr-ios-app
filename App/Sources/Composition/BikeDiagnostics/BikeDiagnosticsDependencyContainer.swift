import BikeDiagnostics
import BikeDomain
import Foundation
import MeasurementPresentation
import SettingsDomain

@MainActor
struct BikeDiagnosticsDependencyContainer {
    func makeBikeDiagnosticsViewModel(
        repository: BikeRepository,
        pinDeriver: any BikePinDeriving,
        profileRepository: any BikeProfileRepository,
        settingsRepository: AppSettingsRepository
    ) -> BikeDiagnosticsViewModel {
        BikeDiagnosticsViewModel(
            useCases: makeUseCases(
                repository: repository,
                pinDeriver: pinDeriver,
                profileRepository: profileRepository,
                settingsRepository: settingsRepository
            ),
            mappers: makeMappers(measurementSystem: .system),
            makeMappers: makeMappers
        )
    }

    private func makeUseCases(
        repository: BikeRepository,
        pinDeriver: any BikePinDeriving,
        profileRepository: any BikeProfileRepository,
        settingsRepository: AppSettingsRepository
    ) -> BikeDiagnosticsUseCases {
        BikeDiagnosticsUseCases(
            start: StartBikeRepositoryUseCase(repository: repository),
            stop: StopBikeRepositoryUseCase(repository: repository),
            connect: ConnectToBikeUseCase(repository: repository),
            disconnect: DisconnectBikeUseCase(repository: repository),
            retrySecurityHandshake: RetryBikeSecurityHandshakeUseCase(repository: repository),
            readTelemetrySnapshot: ReadBikeTelemetrySnapshotUseCase(repository: repository),
            observeTelemetry: ObserveBikeTelemetryUseCase(repository: repository),
            observeConnection: ObserveBikeConnectionUseCase(repository: repository),
            observeDebugEvents: ObserveBikeDebugEventsUseCase(repository: repository),
            derivePin: DeriveBikePinUseCase(pinDeriver: pinDeriver),
            loadProfile: LoadBikeProfileUseCase(repository: profileRepository),
            observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository)
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
                badgesMapper: BikeTelemetryToBadgesMapper(
                    runStateMapper: BikeRunStateToBadgeMapper()
                ),
                rawFlagsMapper: BikeTelemetryToRawFlagsMapper(),
                debugEventMapper: BikeDebugEventToDebugEventViewDataMapper(
                    dateFormatStyle: dateFormatStyle
                )
            )
        )
    }

}
