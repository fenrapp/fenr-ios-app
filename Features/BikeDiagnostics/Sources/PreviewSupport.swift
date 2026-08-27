import AsyncSupport
import BikeDomain
import Foundation
import MeasurementPresentation
import SettingsDomain

@MainActor
enum BikeDiagnosticsPreviewFactory {
    static func makeViewModel() -> BikeDiagnosticsViewModel {
        let repository = PreviewBikeRepository()
        let pinDeriver = PreviewBikePinDeriver()
        let profileRepository = PreviewBikeProfileRepository()
        let viewModel = BikeDiagnosticsViewModel(
            useCases: makeUseCases(
                repository: repository,
                pinDeriver: pinDeriver,
                profileRepository: profileRepository
            ),
            mappers: makeMappers(),
            makeMappers: { _ in makeMappers() }
        )
        viewModel.vinChanged("FENRTEST000000002")
        viewModel.start()
        return viewModel
    }
    static func makeUseCases(
        repository: BikeRepository,
        pinDeriver: any BikePinDeriving,
        profileRepository: any BikeProfileRepository
    ) -> BikeDiagnosticsUseCases {
        BikeDiagnosticsUseCases(
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
            observeSettings: .init(repository: PreviewAppSettingsRepository())
        )
    }

    static func makeMappers() -> BikeDiagnosticsMappers {
        let dateFormatStyle = Date.FormatStyle()
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .second(.twoDigits)
        let locale = Locale(identifier: "en_US")
        let speedFormatter = BikeDiagnosticsSpeedFormatter(
            measurementMapper: VehicleMeasurementMapper(measurementSystem: locale.measurementSystem),
            textFormatter: VehicleMeasurementTextFormatter(locale: locale)
        )
        return BikeDiagnosticsMappers(
            viewState: BikeTelemetryToBikeDiagnosticsViewStateMapper(
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
                debugEventMapper: .init(dateFormatStyle: dateFormatStyle)
            )
        )
    }

}

private actor PreviewAppSettingsRepository: AppSettingsRepository {
    func load() async -> AppSettings { .init() }
    func save(_: AppSettings) async {}
    func observe() async -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(.init())
        }
    }
}

private actor PreviewBikeRepository: BikeRepository {
    private let telemetry = PreviewEventHub<BikeTelemetry>(replaysLatestValue: true)
    private let connection = PreviewEventHub<BikeConnection>(replaysLatestValue: true)
    private let debug = PreviewEventHub<BikeDebugEvent>(replaysLatestValue: true)
    private var isSeeded = false

    func start() async {
        guard !isSeeded else { return }
        isSeeded = true
        await seed()
    }
    func stop() async {}
    func connect(vin: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { await telemetry.stream() }
    func observeConnection() async -> AsyncStream<BikeConnection> { await connection.stream() }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { await debug.stream() }

    private func seed() async {
        let vin = "FENRTEST000000002"
        await connection.send(.init(
            state: .receivingTelemetry(peripheralName: vin),
            peripheralName: vin,
            peripheralIdentifier: UUID(),
            rssi: -58
        ))
        await telemetry.send(.init(
            vin: vin,
            batteryLevel: .known(percent: 91),
            healthLevel: .known(percent: 99),
            mode: .index(3),
            speed: .known(kmh: 42.1, kmhX10: 421),
            motorRPM: .known(3180),
            statusFlags: .init(
                isOn: true,
                isCharging: false,
                isChargerConnected: false,
                isInGear: true,
                isFaultActive: false,
                crawlState: .inactive,
                indicatorState: .init(isRightBlinkerOn: true)
            ),
            rawStatusFlags: .init(misc: 0, indicator: 4, alert: 0, fault: 0, info: 0x0018),
            powerTelemetry: .init(
                electricalPowerWatts: 10_000,
                calculatedPowerUpdatedAt: Date()
            ),
            batteryTelemetry: .init(
                stateOfCharge: .known(percent: 91),
                stateOfHealth: .known(percent: 99),
                dcBusRaw: 4_000,
                dcBusVolts: 400,
                currentRaw: 25,
                currentCandidateAmperes: 25,
                positiveBMS: previewBMS(voltageCandidateRaw: 408),
                negativeBMS: previewBMS(voltageCandidateRaw: 403),
                stateUpdatedAt: Date(),
                signalsUpdatedAt: Date()
            ),
            lastUpdated: Date()
        ))
        await debug.send(.init(title: "Notification", detail: "00006004-5374-6172-4B20-467574757265 4b 5B 00 63 00"))
    }

    private func previewBMS(voltageCandidateRaw: Int) -> BikeBMSSignalsTelemetry {
        .init(
            voltageCandidateRaw: voltageCandidateRaw,
            temperatureRaw: 2_534,
            temperatureCelsius: 25.34,
            humidityRaw: 5_012,
            humidityPercent: 50.12
        )
    }
}

private struct PreviewBikePinDeriver: BikePinDeriving {
    func derivePin(vin: String) -> String { "003421" }
}

private actor PreviewBikeProfileRepository: BikeProfileRepository {
    func loadProfile() async -> BikeProfile? { nil }
    func saveProfile(_ profile: BikeProfile) async {}
    func clearProfile() async {}
}

private typealias PreviewEventHub<Value: Sendable> = AsyncEventHub<Value>
