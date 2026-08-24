@testable import BikeDiagnostics
import BikeDomain
import Foundation
import MeasurementPresentation
import Testing
import TestSupport

@MainActor
@Suite("BikeDiagnostics view model")
struct BikeDiagnosticsTests {
    @Test("VIN changes update PIN and connect availability")
    func vinChangesUpdatePin() {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.vinChanged("abc123")

        #expect(viewModel.viewState.vin == "ABC123")
        #expect(viewModel.viewState.pin == "999999")
        #expect(viewModel.viewState.isConnectEnabled)
    }

    @Test("Start restores the configured bike profile")
    func startRestoresConfiguredProfile() async {
        let repository = FakeBikeDiagnosticsRepository()
        let profileRepository = FakeBikeProfileRepository(profile: .init(vin: "vin123"))
        let viewModel = makeViewModel(repository: repository, profileRepository: profileRepository)

        #expect(viewModel.viewState.vin.isEmpty)
        viewModel.start()
        #expect(await waitUntil {
            viewModel.viewState.vin == "VIN123"
        })

        #expect(viewModel.viewState.vin == "VIN123")
        #expect(viewModel.viewState.pin == "999999")
    }

    @Test("Connection requests do not replace the configured bike profile")
    func connectionRequestDoesNotPersistVIN() async {
        let repository = FakeBikeDiagnosticsRepository()
        let profileRepository = FakeBikeProfileRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: profileRepository)
        viewModel.vinChanged("vin123")

        viewModel.connectTapped()
        #expect(await waitUntil { await repository.connectedVIN() == "VIN123" })

        #expect(await profileRepository.loadProfile() == nil)
    }

    @Test("Init does not start streams")
    func initDoesNotStartStreams() async {
        let repository = FakeBikeDiagnosticsRepository()
        _ = makeViewModel(repository: repository)

        #expect(await repository.startCount() == 0)
        #expect(await repository.telemetryObserverCount() == 0)
    }

    @Test("Observing Diagnostics does not restart the shared BLE repository")
    func observingDoesNotRestartRepository() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)

        viewModel.startObserving()

        #expect(await waitUntil { await repository.telemetryObserverCount() == 1 })
        #expect(await repository.startCount() == 0)
    }

    @Test("Telemetry maps to UI metrics and badges")
    func telemetryMapsToUI() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        #expect(await waitUntil { await repository.telemetryObserverCount() > 0 })

        await repository.sendTelemetry(.init(
            batteryLevel: .known(percent: 91),
            healthLevel: .known(percent: 99),
            mode: .index(3),
            speed: .known(kmh: 42.1, kmhX10: 421),
            motorRPM: .known(3180),
            statusFlags: .init(
                isOn: true,
                isChargerConnected: true,
                isInGear: true,
                isFaultActive: true,
                crawlState: .inactive
            ),
            rawStatusFlags: .init(misc: 12, indicator: 4, alert: 1, fault: 2, info: 0x0018),
            lastUpdated: Date(timeIntervalSince1970: 0)
        ))
        #expect(await waitUntil {
            viewModel.viewState.metrics.contains(
                .init(id: "battery", title: "Battery", value: formattedPercent(91))
            )
        })

        #expect(viewModel.viewState.metrics.contains(
            .init(id: "battery", title: "Battery", value: formattedPercent(91))
        ))
        #expect(viewModel.viewState.metrics.contains(
            .init(id: "soh", title: "SOH", value: formattedPercent(99))
        ))
        #expect(viewModel.viewState.metrics.contains(.init(id: "mode", title: "Mode", value: "3")))
        #expect(viewModel.viewState.metrics.contains(.init(id: "speed", title: "Speed", value: "42,1 km/h")))
        #expect(viewModel.viewState.metrics.contains(.init(id: "rpm", title: "Motor RPM", value: "3180")))
        #expect(viewModel.viewState.metrics.contains {
            $0.id == "updated" && $0.title == "Updated" && $0.value != "--"
        })
        #expect(viewModel.viewState.badges.contains("On"))
        #expect(viewModel.viewState.badges.contains("Charger"))
        #expect(viewModel.viewState.badges.contains("Fault"))
        #expect(viewModel.viewState.rawFlags.contains(.init(id: "misc", title: "miscBits", value: "0x000C")))
    }

    private func formattedPercent(_ value: Int) -> String {
        VehicleMeasurementTextFormatter(locale: .init(identifier: "es_ES")).percentage(value)
    }

    @Test("Missing telemetry values render placeholders")
    func missingValues() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        #expect(await waitUntil { await repository.telemetryObserverCount() > 0 })

        #expect(await waitUntil {
            !viewModel.viewState.metrics.isEmpty
        })

        #expect(viewModel.viewState.metrics.contains(.init(id: "battery", title: "Battery", value: "--")))
        #expect(viewModel.viewState.rawFlags.contains(.init(id: "info", title: "infoBits", value: "0x0000")))
    }

    @Test("Connect and disconnect propagate through use cases")
    func actionsDelegate() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.vinChanged("VIN123")
        viewModel.connectTapped()
        #expect(await waitUntil { await repository.connectedVIN() == "VIN123" })
        viewModel.disconnectTapped()
        #expect(await waitUntil { await repository.didDisconnect() })

        #expect(await repository.connectedVIN() == "VIN123")
        #expect(await repository.didDisconnect())
    }

    @Test("Pair retry propagates through use case")
    func pairRetryDelegates() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.pairRetryTapped()
        #expect(await waitUntil { await repository.didRetrySecurityHandshake() })

        #expect(await repository.didRetrySecurityHandshake())
    }

    @Test("Manual read snapshot propagates through use case")
    func readSnapshotDelegates() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.readSnapshotTapped()
        #expect(await waitUntil { await repository.didReadTelemetrySnapshot() })

        #expect(await repository.didReadTelemetrySnapshot())
    }

    @Test("Debug events expose copyable log text")
    func debugEventsExposeCopyableLog() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        let date = Date(timeIntervalSince1970: 0)
        viewModel.start()

        await repository.sendDebugEvent(.init(
            date: date,
            title: "Subscription",
            detail: "Enabled 00006004-5374-6172-4B20-467574757265"
        ))
        #expect(await waitUntil {
            viewModel.viewState.debugEvents.first?.title == "Subscription"
        })

        let expectedTime = BikeDiagnosticsDateFormatter().string(from: date)
        let debugLogText = viewModel.debugLogText()
        #expect(viewModel.viewState.debugEvents.first?.title == "Subscription")
        #expect(viewModel.viewState.hasDebugLog)
        #expect(debugLogText.contains(expectedTime))
        #expect(debugLogText.contains(" | Subscription | "))
        #expect(debugLogText.contains("Enabled 00006004-5374-6172-4B20-467574757265"))
    }

    @Test("Debug export retains more events than the visible diagnostics list")
    func debugExportRetainsExtendedHistory() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        let eventCount = BikeDiagnosticsConstants.maxVisibleDebugEvents + 1
        let finalPacketDetail = "Packet \(eventCount - 1)"
        viewModel.start()

        for index in 0..<eventCount {
            await repository.sendDebugEvent(.init(
                title: "Notification",
                detail: "Packet \(index)"
            ))
        }
        #expect(await waitUntil {
            viewModel.viewState.debugEvents.first?.detail == finalPacketDetail
        })

        let exportedLines = viewModel.debugLogText()
            .components(separatedBy: BikeDiagnosticsConstants.debugLogLineSeparator)
        #expect(viewModel.viewState.debugEvents.count == BikeDiagnosticsConstants.maxVisibleDebugEvents)
        #expect(exportedLines.count == eventCount)
    }

    @Test("Stop delegates lifecycle cleanup")
    func stopDelegatesLifecycleCleanup() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        viewModel.stop()
        #expect(await waitUntil { await repository.stopCount() == 1 })

        #expect(await repository.stopCount() == 1)
    }

    @Test("Connection UI distinguishes waiting from received telemetry")
    func mapsTelemetryConnectionStatus() {
        let mapper = ConnectionStateToDisplayMapper()
        let connectionMapper = BikeConnectionToConnectionPanelMapper(stateMapper: mapper)

        #expect(mapper.title(for: .authenticating(peripheralName: "VIN")) == "Authenticating")
        #expect(mapper.title(for: .authenticated(peripheralName: "VIN")) == "Authenticated")
        #expect(mapper.title(for: .subscribed(peripheralName: "VIN")) == "Waiting for data")
        #expect(mapper.title(for: .receivingTelemetry(peripheralName: "VIN")) == "Receiving telemetry")
        #expect(mapper.isActive(.receivingTelemetry(peripheralName: "VIN")))
        #expect(!connectionMapper.isVINEditingEnabled(.init(state: .receivingTelemetry(peripheralName: "VIN"))))
        #expect(connectionMapper.isVINEditingEnabled(.init(state: .disconnected(reason: nil))))
    }
}
