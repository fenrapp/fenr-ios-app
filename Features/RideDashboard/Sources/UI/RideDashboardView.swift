import SwiftUI
import UIKit

public struct RideDashboardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var viewModel: RideDashboardViewModel
    @ObservedObject private var currentTripViewModel: CurrentTripCardViewModel
    @ObservedObject private var tripStatisticsViewModel: TripStatisticsCardViewModel
    @ObservedObject private var chargingViewModel: ChargingDashboardViewModel
    @ScaledMetric(relativeTo: .body) private var speedometerTypeScale: CGFloat = 1
    @State private var selectedRidingCard = RidingDashboardCard.speedometer
    @State private var selectedCurrentTripPage = CurrentTripDashboardPage.current
    @State private var currentTripPageResetTask: Task<Void, Never>?
    private let onDiagnostics: () -> Void

    public init(
        viewModel: RideDashboardViewModel,
        currentTripViewModel: CurrentTripCardViewModel,
        tripStatisticsViewModel: TripStatisticsCardViewModel,
        chargingViewModel: ChargingDashboardViewModel,
        onDiagnostics: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.currentTripViewModel = currentTripViewModel
        self.tripStatisticsViewModel = tripStatisticsViewModel
        self.chargingViewModel = chargingViewModel
        self.onDiagnostics = onDiagnostics
    }

    public var body: some View {
        GeometryReader { proxy in
            Group {
                if proxy.size.width <= proxy.size.height {
                    DashboardUnavailableState.rotationRequired
                } else if viewModel.viewState.hasTelemetry {
                    let centerWidth = centerColumnWidth(for: proxy.size)
                    let sideWidth = sideColumnWidth(for: proxy.size, centerWidth: centerWidth)
                    ZStack {
                        DashboardAmbientLighting(indicators: viewModel.viewState.indicators)
                            .ignoresSafeArea()

                        HStack(spacing: .zero) {
                            DashboardBatteryPanel(state: viewModel.viewState.battery)
                                .frame(width: sideWidth)

                            ZStack(alignment: .bottom) {
                                DashboardCenterCard(
                                    centerMode: viewModel.viewState.centerMode,
                                    selectedRidingCard: $selectedRidingCard,
                                    speedometer: viewModel.viewState.speedometer,
                                    showsSpeedSourceIndicator: !DashboardIndicatorStatus.hasActiveIndicators(
                                        viewModel.viewState.indicators
                                    ),
                                    currentTrip: currentTripViewModel.viewState,
                                    selectedCurrentTripPage: $selectedCurrentTripPage,
                                    tripStatistics: tripStatisticsViewModel.viewState,
                                    charging: chargingViewModel.viewState,
                                    referenceSize: proxy.size,
                                    reduceMotion: reduceMotion,
                                    toggleCurrentTripPause: currentTripViewModel.togglePauseCurrentTrip,
                                    resetCurrentTrip: currentTripViewModel.resetCurrentTrip,
                                    setChargePowerLimit: chargingViewModel.setChargePowerLimit(watts:),
                                    setChargeTarget: chargingViewModel.setChargeTarget(percent:)
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .offset(
                                    y: viewModel.viewState.centerMode == .charging
                                        ? physicalCenterOffset(for: proxy.safeAreaInsets)
                                        : .zero
                                )

                                DashboardIndicatorStatus(indicators: viewModel.viewState.indicators)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    .padding(.top, Constants.accessoryEdgePadding)

                                if viewModel.viewState.centerMode == .riding,
                                   selectedRidingCard == .speedometer {
                                    DashboardPowerModeSummary(state: viewModel.viewState.powerMode)
                                        .padding(.bottom, Constants.accessoryEdgePadding)
                                }
                            }
                            .frame(width: centerWidth)

                            DashboardGearPanel(state: viewModel.viewState.gear)
                            .frame(width: sideWidth)
                        }

                    }
                    .overlay(alignment: .bottom) {
                        if viewModel.viewState.centerMode == .riding,
                           selectedRidingCard == .speedometer {
                            DashboardSpeedProgressBar(
                                progress: viewModel.viewState.speedometer.progress
                            )
                            .offset(y: proxy.safeAreaInsets.bottom)
                            .allowsHitTesting(false)
                        }
                    }
                } else {
                    DashboardUnavailableState.disconnected(
                        detail: viewModel.viewState.connectionDetail,
                        onDiagnostics: onDiagnostics
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.startObserving()
            currentTripViewModel.start()
            synchronizeCardLifecycles()
        }
        .onChange(of: viewModel.viewState.centerMode) {
            if viewModel.viewState.centerMode == .riding {
                selectedRidingCard = .speedometer
            }
            scheduleCurrentTripPageResetIfNeeded()
            synchronizeCardLifecycles()
        }
        .onChange(of: selectedRidingCard) {
            scheduleCurrentTripPageResetIfNeeded()
            synchronizeCardLifecycles()
        }
        .onChange(of: selectedCurrentTripPage) {
            synchronizeCardLifecycles()
        }
        .onAppear {
            selectedRidingCard = .speedometer
            selectedCurrentTripPage = .current
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            currentTripPageResetTask?.cancel()
            currentTripPageResetTask = nil
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.stopObserving()
            chargingViewModel.stop()
            currentTripViewModel.setIsVisible(false)
            tripStatisticsViewModel.stop()
        }
    }

    private func synchronizeCardLifecycles() {
        if viewModel.viewState.centerMode == .charging {
            chargingViewModel.start()
        } else {
            chargingViewModel.stop()
        }
        let isCurrentTripCardVisible = viewModel.viewState.centerMode == .riding
            && selectedRidingCard == .currentTrip
        currentTripViewModel.setIsVisible(
            isCurrentTripCardVisible && selectedCurrentTripPage == .current
        )
        tripStatisticsViewModel.setIsVisible(
            isCurrentTripCardVisible && selectedCurrentTripPage == .statistics
        )
    }

    private func scheduleCurrentTripPageResetIfNeeded() {
        currentTripPageResetTask?.cancel()
        currentTripPageResetTask = nil
        let isCurrentTripCardVisible = viewModel.viewState.centerMode == .riding
            && selectedRidingCard == .currentTrip
        guard !isCurrentTripCardVisible, selectedCurrentTripPage != .current else { return }
        currentTripPageResetTask = Task { @MainActor in
            do {
                try await Task.sleep(for: Constants.currentTripPageResetDelay)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  viewModel.viewState.centerMode != .riding
                    || selectedRidingCard != .currentTrip else { return }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                selectedCurrentTripPage = .current
            }
            currentTripPageResetTask = nil
        }
    }

    private func centerColumnWidth(for size: CGSize) -> CGFloat {
        let equalColumnWidth = size.width / Constants.columnCount
        let desiredWidth = max(
            equalColumnWidth,
            Constants.minimumCenterColumnWidth,
            DashboardSpeedometer.minimumContentWidth(
                for: size,
                dynamicTypeScale: speedometerTypeScale
            )
        )
        let maximumWidth = max(
            equalColumnWidth,
            size.width - (Constants.minimumSideColumnWidth * 2)
        )
        return min(desiredWidth, maximumWidth)
    }

    private func sideColumnWidth(for size: CGSize, centerWidth: CGFloat) -> CGFloat {
        (size.width - centerWidth) / 2
    }

    private func physicalCenterOffset(for safeAreaInsets: EdgeInsets) -> CGFloat {
        (safeAreaInsets.bottom - safeAreaInsets.top) / 2
    }

    private enum Constants {
        static let columnCount: CGFloat = 3
        static let minimumCenterColumnWidth: CGFloat = 360
        static let minimumSideColumnWidth: CGFloat = 124
        static let accessoryEdgePadding: CGFloat = 16
        static let currentTripPageResetDelay = Duration.milliseconds(500)
    }
}
