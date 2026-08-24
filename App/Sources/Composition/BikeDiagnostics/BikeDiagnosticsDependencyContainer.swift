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
        let dateFormatter = BikeDiagnosticsDateFormatter()
        let locale = Locale.autoupdatingCurrent
        let speedFormatter = BikeDiagnosticsSpeedFormatter(
            measurementSystem: measurementSystem.resolved(for: locale),
            locale: locale
        )
        return BikeDiagnosticsMappers(
            viewState: BikeTelemetryToBikeDiagnosticsViewStateMapper(
                connectionMapper: BikeConnectionToConnectionPanelMapper(
                    stateMapper: ConnectionStateToDisplayMapper()
                ),
                metricsMapper: BikeTelemetryToMetricsMapper(
                    dateFormatter: dateFormatter,
                    speedFormatter: speedFormatter,
                    measurementTextFormatter: VehicleMeasurementTextFormatter(locale: locale)
                ),
                badgesMapper: BikeTelemetryToBadgesMapper(
                    runStateMapper: BikeRunStateToBadgeMapper()
                ),
                rawFlagsMapper: BikeTelemetryToRawFlagsMapper(),
                debugEventMapper: BikeDebugEventToDebugEventViewDataMapper(
                    dateFormatter: dateFormatter
                )
            )
        )
    }

}
