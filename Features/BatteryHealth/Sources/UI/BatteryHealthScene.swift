import SwiftUI

public struct BatteryHealthScene: View {
    private let destination: BatteryHealthDestination
    @ObservedObject private var viewModel: BatteryHealthViewModel
    private let onNavigate: (BatteryHealthDestination) -> Void

    public init(
        destination: BatteryHealthDestination,
        viewModel: BatteryHealthViewModel,
        onNavigate: @escaping (BatteryHealthDestination) -> Void = { _ in }
    ) {
        self.destination = destination
        self.viewModel = viewModel
        self.onNavigate = onNavigate
    }

    public var body: some View {
        Group {
            switch destination {
            case .overview:
                BatteryHealthOverviewView(
                    state: viewModel.viewState.overview,
                    onNavigate: onNavigate
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
    }
}
