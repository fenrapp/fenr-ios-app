import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport
import VehicleSession

@MainActor
@Suite("System health card view model")
struct SystemHealthCardViewModelTests {
    @Test("Acquires and releases BMS monitoring with visibility")
    func managesMonitoringLifecycle() async {
        let session = SystemHealthVehicleSession()
        let viewModel = makeViewModel(session: session)

        viewModel.setIsVisible(true)
        #expect(await waitUntil { await session.requirements() == [true] })
        viewModel.setIsVisible(false)
        #expect(await waitUntil { await session.requirements() == [true, false] })
    }

    @Test("Publishes current health only while visible")
    func publishesOnlyWhileVisible() async {
        let session = SystemHealthVehicleSession()
        let viewModel = makeViewModel(session: session)
        let healthy = snapshot(healthPercent: 94)

        viewModel.setIsVisible(true)
        await session.send(healthy)
        #expect(await waitUntil(timeout: .seconds(2)) { viewModel.viewState.status == .healthy })

        viewModel.setIsVisible(false)
        await session.send(snapshot(healthPercent: 60), waitsForSubscriber: false)
        try? await Task.sleep(for: .milliseconds(600))
        #expect(viewModel.viewState.status == .healthy)
    }

    @Test("Repeated visibility values do not duplicate monitoring requests")
    func coalescesVisibility() async {
        let session = SystemHealthVehicleSession()
        let viewModel = makeViewModel(session: session)

        viewModel.setIsVisible(true)
        viewModel.setIsVisible(true)
        #expect(await waitUntil { await session.requirements() == [true] })
        viewModel.setIsVisible(false)
        viewModel.setIsVisible(false)
        #expect(await waitUntil { await session.requirements() == [true, false] })
    }

    @Test("Keeps the last health result while a repeat visit refreshes")
    func keepsCachedHealthDuringRefresh() async {
        let session = SystemHealthVehicleSession()
        let viewModel = makeViewModel(session: session)

        viewModel.setIsVisible(true)
        await session.send(snapshot(healthPercent: 94))
        #expect(await waitUntil(timeout: .seconds(2)) {
            viewModel.viewState.stateOfHealthText == "94%"
        })

        viewModel.setIsVisible(false)
        viewModel.setIsVisible(true)
        await session.send(.init(batteryHealthMonitoringState: .starting))
        try? await Task.sleep(for: .milliseconds(600))
        #expect(viewModel.viewState.stateOfHealthText == "94%")

        await session.send(snapshot(healthPercent: 88))
        #expect(await waitUntil(timeout: .seconds(2)) {
            viewModel.viewState.stateOfHealthText == "88%"
        })
    }

    @Test("Keeps SOH and inverter temperature across independent partial datasets")
    func keepsIndependentHealthDatasets() async {
        let session = SystemHealthVehicleSession()
        let viewModel = makeViewModel(session: session)
        viewModel.setIsVisible(true)

        await session.send(.init(
            settings: .init(measurementSystem: .metric),
            batteryHealth: .init(stateOfHealth: .known(percent: 93)),
            batteryHealthMonitoringState: .active
        ))
        #expect(await waitUntil(timeout: .seconds(2)) {
            viewModel.viewState.stateOfHealthText == "93%"
        })

        await session.send(.init(
            telemetry: .init(inverterTemperaturesCelsius: [60, nil, 42]),
            settings: .init(measurementSystem: .metric),
            batteryHealthMonitoringState: .active
        ))
        #expect(await waitUntil(timeout: .seconds(2)) {
            viewModel.viewState.stateOfHealthText == "93%"
                && viewModel.viewState.inverterTemperatureText == "60°C"
        })

        await session.send(.init(
            settings: .init(measurementSystem: .metric),
            batteryHealthMonitoringState: .failed("Synthetic failure")
        ))
        #expect(await waitUntil(timeout: .seconds(2)) {
            viewModel.viewState.status == .unavailable
                && viewModel.viewState.stateOfHealthText == "93%"
                && viewModel.viewState.inverterTemperatureText == "60°C"
        })
    }

    @Test("Releases BMS monitoring when destroyed while visible")
    func releasesMonitoringOnDeinit() async {
        let session = SystemHealthVehicleSession()
        var viewModel: SystemHealthCardViewModel? = makeViewModel(session: session)

        viewModel?.setIsVisible(true)
        #expect(await waitUntil { await session.requirements() == [true] })
        viewModel = nil

        #expect(await waitUntil { await session.requirements() == [true, false] })
    }

    private func makeViewModel(session: SystemHealthVehicleSession) -> SystemHealthCardViewModel {
        SystemHealthCardViewModel(
            vehicleSession: session,
            mapper: RideDashboardMapperFactory.makeSystemHealthMapper(locale: Locale(identifier: "en_GB"))
        )
    }

    private func snapshot(healthPercent: Int) -> VehicleSessionSnapshot {
        .init(
            settings: .init(measurementSystem: .metric),
            batteryHealth: .init(
                stateOfHealth: .known(percent: healthPercent),
                cellVoltages: [
                    .init(position: 1, volts: 3.9),
                    .init(position: 2, volts: 3.9)
                ]
            ),
            batteryHealthMonitoringState: .active
        )
    }
}
