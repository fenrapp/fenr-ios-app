import DesignSystem
import SwiftUI
import UIKit

public struct RideDashboardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var viewModel: RideDashboardViewModel
    @ObservedObject private var chargingViewModel: ChargingDashboardViewModel
    private let onDiagnostics: () -> Void
    private let onSettings: () -> Void

    public init(
        viewModel: RideDashboardViewModel,
        chargingViewModel: ChargingDashboardViewModel,
        onDiagnostics: @escaping () -> Void,
        onSettings: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.chargingViewModel = chargingViewModel
        self.onDiagnostics = onDiagnostics
        self.onSettings = onSettings
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = RideDashboardLayout(
                size: proxy.size,
                displaysBottomMetrics: viewModel.viewState.hasTelemetry
                    && !viewModel.viewState.isCharging
            )
            Group {
                if proxy.size.width <= proxy.size.height {
                    DashboardUnavailableState.rotationRequired
                } else if viewModel.viewState.hasTelemetry {
                    liveDashboard(layout: layout)
                } else {
                    DashboardUnavailableState.disconnected(
                        detail: viewModel.viewState.connectionDetail,
                        onDiagnostics: onDiagnostics
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(DesignColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { viewModel.startObserving() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.stopObserving()
        }
    }

    private func liveDashboard(layout: RideDashboardLayout) -> some View {
        ZStack {
            if viewModel.viewState.isCharging {
                ChargingDashboardBackground()
                    .transition(.opacity)
            }
            dashboardContent(layout: layout)
                .transition(DashboardLiveTransition.transition(reduceMotion: reduceMotion))
            settingsButton
        }
        .padding(.horizontal, layout.horizontalContentPadding)
        .padding(.vertical, layout.verticalContentPadding)
        .animation(
            reduceMotion ? nil : .spring(
                response: RideDashboardLayout.Constants.liveTransitionResponse,
                dampingFraction: RideDashboardLayout.Constants.liveTransitionDamping
            ),
            value: viewModel.viewState.isCharging
        )
    }

    @ViewBuilder
    private func dashboardContent(layout: RideDashboardLayout) -> some View {
        if viewModel.viewState.isCharging {
            DashboardShell(
                layout: layout,
                sideMetrics: {
                    ChargingDashboardMetricsColumn(
                        viewState: chargingViewModel.viewState,
                        compact: layout.usesCompactSideMetrics
                    )
                },
                gear: {
                    DashboardGearColumn(state: viewModel.viewState.gear)
                },
                instrument: {
                    DashboardChargingGauge(
                        state: chargingViewModel.viewState.gauge,
                        reduceMotion: reduceMotion,
                        setPowerLimit: chargingViewModel.setChargePowerLimit(watts:),
                        setChargeTarget: chargingViewModel.setChargeTarget(percent:)
                    )
                },
                indicators: { indicatorRail },
                bottomMetrics: { EmptyView() }
            )
            .task { chargingViewModel.start() }
            .onDisappear { chargingViewModel.stop() }
        } else {
            DashboardShell(
                layout: layout,
                sideMetrics: {
                    RideDashboardMetricsColumn(
                        batteryPercent: viewModel.viewState.batteryPercent,
                        odometer: viewModel.viewState.odometer,
                        compact: layout.usesCompactSideMetrics
                    )
                },
                gear: {
                    DashboardGearColumn(state: viewModel.viewState.gear)
                },
                instrument: {
                    DashboardSpeedometer(
                        state: viewModel.viewState.speedometer,
                        reduceMotion: reduceMotion
                    )
                },
                indicators: { indicatorRail },
                bottomMetrics: {
                    DashboardPowerModeStrip(state: viewModel.viewState.powerMode)
                }
            )
        }
    }

    private var settingsButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: RideDashboardLayout.Constants.settingsIconSize, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignColor.secondaryText)
                .accessibilityLabel("Settings")
            }
            Spacer()
        }
    }

    private var indicatorRail: DashboardIndicatorRail {
        DashboardIndicatorRail(indicators: viewModel.viewState.indicators)
    }
}
