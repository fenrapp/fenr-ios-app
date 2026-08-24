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
            let layout = RideDashboardLayout(size: proxy.size)
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
            if viewModel.viewState.runState == .charging {
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
            value: viewModel.viewState.runState == .charging
        )
    }

    @ViewBuilder
    private func dashboardContent(layout: RideDashboardLayout) -> some View {
        if viewModel.viewState.runState == .charging {
            DashboardShell(
                layout: layout,
                sideMetrics: {
                    ChargingDashboardMetricsColumn(
                        viewState: chargingViewModel.viewState,
                        compact: layout.usesCompactSideMetrics
                    )
                },
                gear: {
                    DashboardGearColumn(
                        runState: viewModel.viewState.runState,
                        modeIndex: viewModel.viewState.modeIndex
                    )
                },
                instrument: {
                    DashboardGauge(
                        mode: .charging(
                            percentage: chargingViewModel.viewState.batteryPercent,
                            targetPercentage: chargingViewModel.viewState.targetStateOfChargePercent,
                            estimatedTimeRemaining: chargingViewModel.viewState.estimatedTimeRemaining,
                            isBalancingAtFullCharge: chargingViewModel.viewState.isBalancingAtFullCharge
                        ),
                        reduceMotion: reduceMotion
                    )
                },
                indicators: { indicatorRail }
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
                    DashboardGearColumn(
                        runState: viewModel.viewState.runState,
                        modeIndex: viewModel.viewState.modeIndex
                    )
                },
                instrument: {
                    DashboardSpeedometer(
                        speed: viewModel.viewState.speed,
                        maximum: viewModel.viewState.speedometerMaximum,
                        reduceMotion: reduceMotion
                    )
                },
                indicators: { indicatorRail }
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
        DashboardIndicatorRail(
            isHighBeamOn: viewModel.viewState.isHighBeamOn,
            isLeftBlinkerOn: viewModel.viewState.isLeftBlinkerOn,
            isBrakeActive: viewModel.viewState.isBrakeActive,
            isRightBlinkerOn: viewModel.viewState.isRightBlinkerOn,
            isFaultActive: viewModel.viewState.isFaultActive
        )
    }
}
