import DesignSystem
import SwiftUI
import UIKit

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
    @ObservedObject private var bikeLockViewModel: BikeLockCardViewModel
    @ScaledMetric(relativeTo: .body) private var speedometerTypeScale: CGFloat = 1
    @State private var cardSelection = DashboardCardSelectionState()
    @State private var hiddenPageResetTask: Task<Void, Never>?
    private let onSettings: () -> Void
    private let onDiagnostics: () -> Void
    private let onNavigation: () -> Void
    private let isNavigationActive: Bool
    private let isPresentationActive: Bool
}

public extension RideDashboardView {
    init(
        feature: RideDashboardFeatureModel,
        onSettings: @escaping () -> Void = {},
        onNavigation: @escaping () -> Void = {},
        isNavigationActive: Bool = false,
        isPresentationActive: Bool = true,
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
        _bikeLockViewModel = ObservedObject(wrappedValue: feature.bikeLockViewModel)
        _cardSelection = State(initialValue: .init(layout: feature.dashboardViewModel.cardLayout))
        self.onSettings = onSettings
        self.onNavigation = onNavigation
        self.isNavigationActive = isNavigationActive
        self.isPresentationActive = isPresentationActive
        self.onDiagnostics = onDiagnostics
    }
}

extension RideDashboardView {
    public var body: some View {
        GeometryReader { proxy in
            DashboardRideChrome(
                state: viewModel.viewState,
                deviceBattery: deviceBatteryViewModel.viewState,
                toggleDeviceBatteryDisplayMode: deviceBatteryViewModel.toggleDisplayMode,
                onSettings: onSettings
            ) {
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
                            VStack(spacing: DashboardSideStatusLayoutMetrics.spacing) {
                                DashboardBatteryPanel(
                                    state: viewModel.viewState.battery,
                                    showsEstimatedRange: viewModel.viewState.showsEstimatedRangeBatteryIndicator,
                                    estimatedRange: rangeViewModel.summary
                                )

                                if viewModel.viewState.centerMode == .riding,
                                   cardSelection.showsCompactSpeed(viewModel.viewState.showsCompactSpeedReadout) {
                                    DashboardCompactSpeedReadout(state: viewModel.viewState.speedometer)
                                        .transition(.opacity)
                                }
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
                                    bikeLock: bikeLockViewModel.viewState,
                                    bikeLockSecurityOptions: bikeLockViewModel.securityOptions,
                                    charging: chargingViewModel.viewState,
                                    referenceSize: proxy.size,
                                    reduceMotion: reduceMotion,
                                    toggleCurrentTripPause: currentTripViewModel.togglePauseCurrentTrip,
                                    resetCurrentTrip: currentTripViewModel.resetCurrentTrip,
                                    calibrateDynamics: dynamicsViewModel.calibrate,
                                    setChargePowerLimit: chargingViewModel.setChargePowerLimit(watts:),
                                    setChargeTarget: chargingViewModel.setChargeTarget(percent:),
                                    openNavigation: onNavigation,
                                    isNavigationActive: isNavigationActive,
                                    performBikeLockAction: bikeLockViewModel.performPrimaryAction,
                                    configureBikeLock: bikeLockViewModel.configure(securityOptionID:pin:),
                                    submitBikeLockPIN: bikeLockViewModel.submitPIN,
                                    dismissBikeLockSheet: bikeLockViewModel.dismissSheet
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
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            feature.start()
            if isPresentationActive {
                feature.setPresentationActive(true)
                synchronizeCardLifecycles()
            }
        }
        .onChange(of: isPresentationActive) {
            if isPresentationActive {
                feature.setPresentationActive(true)
                synchronizeCardLifecycles()
            } else {
                feature.setPresentationActive(false)
            }
        }
        .onChange(of: viewModel.viewState.centerMode) {
            if viewModel.viewState.centerMode == .riding {
                if bikeLockViewModel.viewState.isAvailable,
                   bikeLockViewModel.viewState.isLocked {
                    cardSelection.ridingCard = .bikeLock
                } else {
                    cardSelection.selectSpeedometer()
                }
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
        .onChange(of: bikeLockViewModel.viewState.isAvailable) {
            if !bikeLockViewModel.viewState.isAvailable,
               cardSelection.ridingCard == .bikeLock {
                cardSelection.selectSpeedometer()
            }
        }
        .onChange(of: bikeLockViewModel.viewState.isLocked) {
            guard viewModel.viewState.centerMode == .riding,
                  bikeLockViewModel.viewState.isAvailable else { return }
            if bikeLockViewModel.viewState.isLocked {
                cardSelection.ridingCard = .bikeLock
            } else if cardSelection.ridingCard == .bikeLock {
                cardSelection.selectSpeedometer()
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            hiddenPageResetTask?.cancel()
            hiddenPageResetTask = nil
            UIApplication.shared.isIdleTimerDisabled = false
            feature.setPresentationActive(false)
        }
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

    private enum Constants {
        static let accessoryEdgePadding: CGFloat = 16
        static let hiddenPageResetDelay = Duration.milliseconds(500)
    }
}
