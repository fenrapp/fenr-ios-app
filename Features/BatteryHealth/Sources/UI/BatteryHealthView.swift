import DesignSystem
import SwiftUI
import UIKit

public struct BatteryHealthView: View {
    @ObservedObject private var viewModel: BatteryHealthViewModel

    public init(viewModel: BatteryHealthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                SurfacePanel(title: BatteryHealthText.summary) {
                    BatteryHealthMetricsGridView(metrics: viewModel.viewState.summary)
                }
                if !viewModel.viewState.charging.isEmpty {
                    SurfacePanel(title: BatteryHealthText.charging) {
                        BatteryHealthMetricsGridView(metrics: viewModel.viewState.charging)
                    }
                }
                SurfacePanel(title: BatteryHealthText.pack) {
                    BatteryHealthMetricsGridView(metrics: viewModel.viewState.packStatus)
                }
                SurfacePanel(title: BatteryHealthText.cells) {
                    if viewModel.viewState.cells.isEmpty {
                        Text(BatteryHealthText.noValidatedCells)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        BatteryCellsGridView(cells: viewModel.viewState.cells)
                    }
                }
                SurfacePanel(title: BatteryHealthText.temperatures) {
                    if viewModel.viewState.temperatures.isEmpty {
                        Text(BatteryHealthText.noValidatedTemperatures)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        BatteryTemperaturesGridView(temperatures: viewModel.viewState.temperatures)
                    }
                }
                SurfacePanel(title: BatteryHealthText.dataSources) {
                    BatteryHealthDatasetListView(datasets: viewModel.viewState.datasets)
                    copyButton
                    if let monitorError = viewModel.viewState.monitorError {
                        Text(monitorError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(Constants.screenPadding)
            .frame(maxWidth: Constants.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(DesignColor.groupedSurface)
        .navigationTitle("Battery Health")
        .navigationBarTitleDisplayMode(.inline)
        .dynamicTypeSize(.medium ... .large)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var copyButton: some View {
        Button(action: copyLog) {
            Label(BatteryHealthText.copyLog, systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.captureLogText().isEmpty)
    }

    private func copyLog() {
        UIPasteboard.general.string = viewModel.captureLogText()
    }

    private enum Constants {
        static let sectionSpacing = DesignSpace.small
        static let screenPadding = DesignSpace.small
        static let contentMaxWidth: CGFloat = 640
    }
}

#Preview("Battery Health") {
    NavigationStack {
        BatteryHealthView(viewModel: .preview())
    }
}
