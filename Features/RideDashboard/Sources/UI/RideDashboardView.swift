import SwiftUI
import UIKit

public struct RideDashboardView: View {
    @ObservedObject private var viewModel: RideDashboardViewModel
    @ScaledMetric(relativeTo: .body) private var speedometerTypeScale: CGFloat = 1
    private let onDiagnostics: () -> Void

    public init(
        viewModel: RideDashboardViewModel,
        onDiagnostics: @escaping () -> Void
    ) {
        self.viewModel = viewModel
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
                                DashboardSpeedometer(
                                    state: viewModel.viewState.speedometer,
                                    referenceSize: proxy.size
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                                DashboardIndicatorStatus(indicators: viewModel.viewState.indicators)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    .padding(.top, Constants.accessoryEdgePadding)

                                DashboardPowerModeSummary(state: viewModel.viewState.powerMode)
                                    .padding(.bottom, Constants.accessoryEdgePadding)
                            }
                            .frame(width: centerWidth)

                            DashboardGearPanel(state: viewModel.viewState.gear)
                            .frame(width: sideWidth)
                        }

                    }
                    .overlay(alignment: .bottom) {
                        if !viewModel.viewState.isCharging {
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
        .task { viewModel.startObserving() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.stopObserving()
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

    private enum Constants {
        static let columnCount: CGFloat = 3
        static let minimumCenterColumnWidth: CGFloat = 360
        static let minimumSideColumnWidth: CGFloat = 124
        static let accessoryEdgePadding: CGFloat = 16
    }
}
