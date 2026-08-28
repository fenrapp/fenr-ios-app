import DesignSystem
import SwiftUI
import UIKit

@MainActor
public struct RideDashboardScene: View {
    @StateObject private var feature: RideDashboardFeatureModel
    private let onSettings: () -> Void
    private let onDiagnostics: () -> Void

    public init(
        factory: any RideDashboardFeatureBuilding,
        onSettings: @escaping () -> Void = {},
        onDiagnostics: @escaping () -> Void
    ) {
        _feature = StateObject(wrappedValue: factory.makeFeature())
        self.onSettings = onSettings
        self.onDiagnostics = onDiagnostics
    }

    public var body: some View {
        RideDashboardView(
            feature: feature,
            onSettings: onSettings,
            onDiagnostics: onDiagnostics
        )
    }
}

public struct RideDashboardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let feature: RideDashboardFeatureModel
    @ObservedObject private var viewModel: RideDashboardViewModel
    @ObservedObject private var deviceBatteryViewModel: DashboardDeviceBatteryViewModel
    @ObservedObject private var currentTripViewModel: CurrentTripCardViewModel
    @ObservedObject private var tripStatisticsViewModel: TripStatisticsCardViewModel
    @ObservedObject private var efficiencyViewModel: EfficiencyCardViewModel
    @ObservedObject private var rangeViewModel: RangeCardViewModel
    @ObservedObject private var systemHealthViewModel: SystemHealthCardViewModel
    @ObservedObject private var dynamicsViewModel: RideDynamicsCardViewModel
    @ObservedObject private var chargingViewModel: ChargingDashboardViewModel
    @ScaledMetric(relativeTo: .body) private var speedometerTypeScale: CGFloat = 1
    @State private var cardSelection = DashboardCardSelectionState()
    @State private var hiddenPageResetTask: Task<Void, Never>?
    private let onSettings: () -> Void
    private let onDiagnostics: () -> Void

    public init(
        feature: RideDashboardFeatureModel,
        onSettings: @escaping () -> Void = {},
        onDiagnostics: @escaping () -> Void
    ) {
        self.feature = feature
        _viewModel = ObservedObject(wrappedValue: feature.dashboardViewModel)
        _deviceBatteryViewModel = ObservedObject(wrappedValue: feature.deviceBatteryViewModel)
        _currentTripViewModel = ObservedObject(wrappedValue: feature.currentTripViewModel)
        _tripStatisticsViewModel = ObservedObject(wrappedValue: feature.tripStatisticsViewModel)
        _efficiencyViewModel = ObservedObject(wrappedValue: feature.efficiencyViewModel)
        _rangeViewModel = ObservedObject(wrappedValue: feature.rangeViewModel)
        _systemHealthViewModel = ObservedObject(wrappedValue: feature.systemHealthViewModel)
        _dynamicsViewModel = ObservedObject(wrappedValue: feature.dynamicsViewModel)
        _chargingViewModel = ObservedObject(wrappedValue: feature.chargingViewModel)
        self.onSettings = onSettings
        self.onDiagnostics = onDiagnostics
    }

    public var body: some View {
        GeometryReader { proxy in
            Group {
                if proxy.size.width <= proxy.size.height {
                    DashboardUnavailableState.rotationRequired
                } else if viewModel.viewState.hasTelemetry {
                    let layout = DashboardLayoutMetrics(
                        size: proxy.size,
                        safeAreaInsets: proxy.safeAreaInsets,
                        speedometerTypeScale: speedometerTypeScale
                    )
                    ZStack {
                        DashboardAmbientLighting(indicators: viewModel.viewState.indicators)
                            .ignoresSafeArea()

                        HStack(spacing: .zero) {
                            VStack(spacing: Constants.speedToBatterySpacing) {
                                if viewModel.viewState.centerMode == .riding,
                                   cardSelection.ridingCard != .speedometer {
                                    DashboardCompactSpeedReadout(state: viewModel.viewState.speedometer)
                                        .transition(.opacity)
                                }

                                DashboardBatteryPanel(
                                    state: viewModel.viewState.battery,
                                    displayMode: viewModel.viewState.batteryIndicatorMode,
                                    estimatedRange: rangeViewModel.summary
                                )
                            }
                            .frame(width: layout.sideColumnWidth)

                            ZStack(alignment: .bottom) {
                                DashboardCenterCard(
                                    centerMode: viewModel.viewState.centerMode,
                                    cardLayout: viewModel.cardLayout,
                                    selectedRidingCard: $cardSelection.ridingCard,
                                    speedometer: viewModel.viewState.speedometer,
                                    showsSpeedSourceIndicator: !DashboardIndicatorStatus.hasActiveIndicators(
                                        viewModel.viewState.indicators
                                    ),
                                    currentTrip: currentTripViewModel.viewState,
                                    selectedCurrentTripPage: $cardSelection.currentTripPage,
                                    tripStatistics: tripStatisticsViewModel.viewState,
                                    selectedEfficiencyPage: $cardSelection.efficiencyPage,
                                    efficiency: efficiencyViewModel.viewState,
                                    selectedRangePage: $cardSelection.rangePage,
                                    range: rangeViewModel.viewState,
                                    selectedSystemHealthPage: $cardSelection.systemHealthPage,
                                    systemHealth: systemHealthViewModel.viewState,
                                    selectedDynamicsPage: $cardSelection.dynamicsPage,
                                    dynamics: dynamicsViewModel.viewState,
                                    charging: chargingViewModel.viewState,
                                    referenceSize: proxy.size,
                                    reduceMotion: reduceMotion,
                                    toggleCurrentTripPause: currentTripViewModel.togglePauseCurrentTrip,
                                    resetCurrentTrip: currentTripViewModel.resetCurrentTrip,
                                    calibrateDynamics: dynamicsViewModel.calibrate,
                                    setChargePowerLimit: chargingViewModel.setChargePowerLimit(watts:),
                                    setChargeTarget: chargingViewModel.setChargeTarget(percent:)
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .offset(
                                    y: viewModel.viewState.centerMode == .charging
                                        ? layout.chargingCenterOffset
                                        : .zero
                                )

                                if viewModel.viewState.centerMode == .riding,
                                   cardSelection.ridingCard == .speedometer {
                                    DashboardIndicatorStatus(indicators: viewModel.viewState.indicators)
                                        .frame(maxHeight: .infinity, alignment: .top)
                                        .padding(.top, Constants.accessoryEdgePadding)
                                }

                                if viewModel.viewState.centerMode == .riding,
                                   cardSelection.ridingCard == .speedometer {
                                    DashboardPowerModeSummary(state: viewModel.viewState.powerMode)
                                        .padding(.bottom, Constants.accessoryEdgePadding)
                                }
                            }
                            .frame(width: layout.centerColumnWidth)

                            DashboardRightStatusColumn(
                                gear: viewModel.viewState.gear,
                                powerMode: viewModel.viewState.powerMode,
                                showsPowerMode: viewModel.viewState.centerMode == .riding
                                    && cardSelection.ridingCard != .speedometer
                            )
                            .frame(width: layout.sideColumnWidth)
                        }

                    }
                    .overlay(alignment: .bottom) {
                        if viewModel.viewState.centerMode == .riding,
                           cardSelection.ridingCard == .speedometer {
                            DashboardProgressBar(state: viewModel.viewState.progressBar)
                            .offset(y: proxy.safeAreaInsets.bottom)
                            .allowsHitTesting(false)
                        }
                    }
                } else if viewModel.viewState.showsConnectionProgress {
                    DashboardUnavailableState.connecting(
                        detail: viewModel.viewState.connectionDetail
                    )
                } else {
                    DashboardUnavailableState.disconnected(
                        detail: viewModel.viewState.connectionDetail,
                        onDiagnostics: onDiagnostics
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay(alignment: .topLeading) {
                DashboardRideHeader(
                    deviceBattery: deviceBatteryViewModel.viewState
                )
                    .padding(Constants.accessoryEdgePadding)
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.viewState.hasTelemetry {
                    DashboardOdometerLabel(state: viewModel.viewState.odometer)
                        .padding(Constants.accessoryEdgePadding)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if viewModel.viewState.temperatureSummary.hasValues {
                    DashboardRideTemperatureSummary(state: viewModel.viewState.temperatureSummary)
                        .padding(Constants.accessoryEdgePadding)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: onSettings) {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(Constants.accessoryEdgePadding)
                .accessibilityIdentifier("dashboard.settings")
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            feature.start()
            synchronizeCardLifecycles()
        }
        .onChange(of: viewModel.viewState.centerMode) {
            if viewModel.viewState.centerMode == .riding {
                cardSelection.selectSpeedometer()
            }
            scheduleHiddenPageResetIfNeeded()
            synchronizeCardLifecycles()
        }
        .onChange(of: cardSelection) {
            scheduleHiddenPageResetIfNeeded()
            synchronizeCardLifecycles()
        }
        .onChange(of: viewModel.cardLayout) {
            cardSelection.apply(layout: viewModel.cardLayout)
            scheduleHiddenPageResetIfNeeded()
            synchronizeCardLifecycles()
        }
        .onAppear {
            cardSelection = .init(layout: viewModel.cardLayout)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            hiddenPageResetTask?.cancel()
            hiddenPageResetTask = nil
            UIApplication.shared.isIdleTimerDisabled = false
            feature.stopPresentation()
        }
    }
}

private struct DashboardRideTemperatureSummary: View {
    let state: RideDashboardViewState.TemperatureSummary

    var body: some View {
        DashboardTemperatureCapsule {
            HStack(spacing: Constants.itemSpacing) {
                if let batteryTemperatureText = state.batteryTemperatureText {
                    DashboardTemperatureItem(
                        text: batteryTemperatureText,
                        systemImage: "battery.100percent",
                        accessibilityLabel: "Battery temperature"
                    )
                }

                if state.batteryTemperatureText != nil, state.inverterTemperatureText != nil {
                    Divider()
                        .frame(height: Constants.separatorHeight)
                }

                if let inverterTemperatureText = state.inverterTemperatureText {
                    DashboardTemperatureItem(
                        text: inverterTemperatureText,
                        systemImage: "bolt.horizontal.fill",
                        accessibilityLabel: "Inverter temperature"
                    )
                }
            }
        }
    }

    private enum Constants {
        static let itemSpacing: CGFloat = 5
        static let separatorHeight: CGFloat = 13
    }
}

private struct DashboardTemperatureItem: View {
    let text: String
    let systemImage: String
    let accessibilityLabel: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(text)
    }
}

private struct DashboardTemperatureCapsule<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(.system(
                size: DashboardTemperatureCapsuleConstants.valueFontSize,
                weight: .semibold,
                design: .rounded
            ))
            .foregroundStyle(DesignColor.primaryText)
            .monospacedDigit()
            .padding(.horizontal, DashboardTemperatureCapsuleConstants.horizontalPadding)
            .frame(height: DashboardTemperatureCapsuleConstants.height)
            .background {
                Capsule()
                    .fill(DesignColor.groupedSurface)
            }
            .overlay {
                Capsule()
                    .stroke(DesignColor.border, lineWidth: DashboardTemperatureCapsuleConstants.outlineWidth)
            }
    }
}

private enum DashboardTemperatureCapsuleConstants {
    static let height: CGFloat = 29
    static let horizontalPadding: CGFloat = 10
    static let outlineWidth: CGFloat = 1.25
    static let valueFontSize: CGFloat = 14
}

private extension RideDashboardViewState.TemperatureSummary {
    var hasValues: Bool {
        batteryTemperatureText != nil || inverterTemperatureText != nil
    }
}

private extension RideDashboardView {
    func synchronizeCardLifecycles() {
        feature.synchronizeCardLifecycles(
            centerMode: viewModel.viewState.centerMode,
            selection: cardSelection
        )
    }

    func scheduleHiddenPageResetIfNeeded() {
        hiddenPageResetTask?.cancel()
        hiddenPageResetTask = nil
        guard cardSelection.needsHiddenPageReset(
            in: viewModel.viewState.centerMode,
            layout: viewModel.cardLayout
        ) else { return }
        hiddenPageResetTask = Task { @MainActor in
            do {
                try await Task.sleep(for: Constants.hiddenPageResetDelay)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  cardSelection.needsHiddenPageReset(
                    in: viewModel.viewState.centerMode,
                    layout: viewModel.cardLayout
                  ) else { return }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                cardSelection.resetHiddenPages(
                    in: viewModel.viewState.centerMode,
                    layout: viewModel.cardLayout
                )
            }
            hiddenPageResetTask = nil
        }
    }

    enum Constants {
        static let accessoryEdgePadding: CGFloat = 16
        static let speedToBatterySpacing: CGFloat = 10
        static let hiddenPageResetDelay = Duration.milliseconds(500)
    }
}
