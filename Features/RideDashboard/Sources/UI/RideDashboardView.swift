import SwiftUI
import UIKit

@MainActor
public struct RideDashboardScene: View {
    @StateObject private var feature: RideDashboardFeatureModel
    private let showsTelemetryButton: Bool
    private let onDiagnostics: () -> Void

    public init(
        factory: any RideDashboardFeatureBuilding,
        showsTelemetryButton: Bool = false,
        onDiagnostics: @escaping () -> Void
    ) {
        _feature = StateObject(wrappedValue: factory.makeFeature())
        self.showsTelemetryButton = showsTelemetryButton
        self.onDiagnostics = onDiagnostics
    }

    public var body: some View {
        RideDashboardView(
            feature: feature,
            showsTelemetryButton: showsTelemetryButton,
            onDiagnostics: onDiagnostics
        )
    }
}

public struct RideDashboardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let feature: RideDashboardFeatureModel
    @ObservedObject private var viewModel: RideDashboardViewModel
    @ObservedObject private var currentTripViewModel: CurrentTripCardViewModel
    @ObservedObject private var tripStatisticsViewModel: TripStatisticsCardViewModel
    @ObservedObject private var efficiencyViewModel: EfficiencyCardViewModel
    @ObservedObject private var rangeViewModel: RangeCardViewModel
    @ObservedObject private var dynamicsViewModel: RideDynamicsCardViewModel
    @ObservedObject private var chargingViewModel: ChargingDashboardViewModel
    @ScaledMetric(relativeTo: .body) private var speedometerTypeScale: CGFloat = 1
    @State private var cardSelection = DashboardCardSelectionState()
    @State private var hiddenPageResetTask: Task<Void, Never>?
    private let showsTelemetryButton: Bool
    private let onDiagnostics: () -> Void

    public init(
        feature: RideDashboardFeatureModel,
        showsTelemetryButton: Bool = false,
        onDiagnostics: @escaping () -> Void
    ) {
        self.feature = feature
        _viewModel = ObservedObject(wrappedValue: feature.dashboardViewModel)
        _currentTripViewModel = ObservedObject(wrappedValue: feature.currentTripViewModel)
        _tripStatisticsViewModel = ObservedObject(wrappedValue: feature.tripStatisticsViewModel)
        _efficiencyViewModel = ObservedObject(wrappedValue: feature.efficiencyViewModel)
        _rangeViewModel = ObservedObject(wrappedValue: feature.rangeViewModel)
        _dynamicsViewModel = ObservedObject(wrappedValue: feature.dynamicsViewModel)
        _chargingViewModel = ObservedObject(wrappedValue: feature.chargingViewModel)
        self.showsTelemetryButton = showsTelemetryButton
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
                            DashboardBatteryPanel(state: viewModel.viewState.battery)
                                .frame(width: layout.sideColumnWidth)

                            ZStack(alignment: .bottom) {
                                DashboardCenterCard(
                                    centerMode: viewModel.viewState.centerMode,
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

                                DashboardIndicatorStatus(indicators: viewModel.viewState.indicators)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    .padding(.top, Constants.accessoryEdgePadding)

                                if viewModel.viewState.centerMode == .riding,
                                   cardSelection.ridingCard == .speedometer {
                                    DashboardPowerModeSummary(state: viewModel.viewState.powerMode)
                                        .padding(.bottom, Constants.accessoryEdgePadding)
                                }
                            }
                            .frame(width: layout.centerColumnWidth)

                            DashboardGearPanel(state: viewModel.viewState.gear)
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
                } else {
                    DashboardUnavailableState.disconnected(
                        detail: viewModel.viewState.connectionDetail,
                        onDiagnostics: onDiagnostics
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay(alignment: .topTrailing) {
                if showsTelemetryButton {
                    Button(action: onDiagnostics) {
                        Label("Telemetry", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(Constants.accessoryEdgePadding)
                    .accessibilityIdentifier("dashboard.telemetry")
                }
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
        .onAppear {
            cardSelection = .init()
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
        guard cardSelection.needsHiddenPageReset(in: viewModel.viewState.centerMode) else { return }
        hiddenPageResetTask = Task { @MainActor in
            do {
                try await Task.sleep(for: Constants.hiddenPageResetDelay)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  cardSelection.needsHiddenPageReset(in: viewModel.viewState.centerMode) else { return }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                cardSelection.resetHiddenPages(in: viewModel.viewState.centerMode)
            }
            hiddenPageResetTask = nil
        }
    }

    enum Constants {
        static let accessoryEdgePadding: CGFloat = 16
        static let hiddenPageResetDelay = Duration.milliseconds(500)
    }
}
