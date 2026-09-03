import SwiftUI

public struct BatteryHealthScene: View {
    private let destination: BatteryHealthDestination
    @ObservedObject private var viewModel: BatteryHealthViewModel
    private let isPresentationActive: Bool
    private let onNavigation: (BatteryHealthNavigationEvent) -> Void

    public init(
        destination: BatteryHealthDestination,
        viewModel: BatteryHealthViewModel,
        isPresentationActive: Bool,
        onNavigation: @escaping (BatteryHealthNavigationEvent) -> Void
    ) {
        self.destination = destination
        self.viewModel = viewModel
        self.isPresentationActive = isPresentationActive
        self.onNavigation = onNavigation
    }

    public var body: some View {
        Group {
            switch destination {
            case .overview:
                BatteryHealthOverviewView(
                    state: viewModel.viewState.overview,
                    onNavigate: { onNavigation(.show($0)) }
                )
            case .cells:
                BatteryHealthCellsView(state: viewModel.viewState.cellsDetail)
            case .thermal:
                BatteryHealthThermalView(state: viewModel.viewState.thermalDetail)
            case .charging:
                BatteryHealthChargingView(
                    state: viewModel.viewState.chargingDetail,
                    setPowerLimit: viewModel.setChargePowerLimit(watts:),
                    setChargeTarget: viewModel.setChargeTarget(percent:)
                )
            case .rawData:
                BatteryHealthRawDataView(
                    state: viewModel.viewState.rawDataDetail,
                    exportText: viewModel.captureLogText()
                )
            }
        }
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(destination == .overview ? .large : .inline)
        .task { synchronizePresentation() }
        .onChange(of: isPresentationActive) { synchronizePresentation() }
        .onDisappear {
            if ownsPresentationLifecycle, !isPresentationActive {
                viewModel.setPresentationActive(false)
            }
        }
    }

    private func synchronizePresentation() {
        guard ownsPresentationLifecycle else { return }
        viewModel.setPresentationActive(isPresentationActive)
    }

    private var ownsPresentationLifecycle: Bool {
        destination == .overview
    }
}
