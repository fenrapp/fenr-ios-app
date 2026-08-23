import DesignSystem
import SwiftUI

struct BatteryHealthDatasetListView: View {
    let datasets: [BatteryHealthDatasetViewData]

    var body: some View {
        VStack(spacing: Constants.rowSpacing) {
            ForEach(datasets) { dataset in
                HStack(spacing: Constants.rowSpacing) {
                    Text(dataset.title)
                        .font(.callout)
                    Spacer(minLength: Constants.minimumSpacerLength)
                    Text(statusText(dataset.status))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(statusColor(dataset.status))
                }
                if dataset.id != datasets.last?.id {
                    Divider()
                }
            }
        }
    }

    private func statusText(_ status: BatteryHealthDatasetViewData.Status) -> String {
        switch status {
        case .awaitingSample: BatteryHealthText.awaitingSample
        case .captured(let text), .validated(let text), .failed(let text): text
        }
    }

    private func statusColor(_ status: BatteryHealthDatasetViewData.Status) -> Color {
        switch status {
        case .awaitingSample: .secondary
        case .captured: .orange
        case .validated: .green
        case .failed: .red
        }
    }

    private enum Constants {
        static let rowSpacing = DesignSpace.extraSmall
        static let minimumSpacerLength = DesignSpace.extraSmall
    }
}

#Preview("Battery Health datasets") {
    BatteryHealthDatasetListView(datasets: [
        .init(id: "cells", title: "Cell voltages", status: .captured("Captured 200 B")),
        .init(id: "temperature", title: "Temperatures", status: .awaitingSample)
    ])
    .padding()
}
