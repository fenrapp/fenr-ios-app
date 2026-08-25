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
                    Text(dataset.status.text)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(statusColor(dataset.status.emphasis))
                }
                if dataset.id != datasets.last?.id {
                    Divider()
                }
            }
        }
    }

    private func statusColor(_ emphasis: BatteryHealthStatusEmphasis) -> Color {
        switch emphasis {
        case .neutral: .secondary
        case .warning: .orange
        case .positive: .green
        }
    }

    private enum Constants {
        static let rowSpacing = DesignSpace.extraSmall
        static let minimumSpacerLength = DesignSpace.extraSmall
    }
}

#Preview("Battery Health datasets") {
    BatteryHealthDatasetListView(datasets: [
        .init(
            id: "cells",
            title: "Cell voltages",
            status: .init(text: "Captured 200 B", emphasis: .warning)
        ),
        .init(
            id: "temperature",
            title: "Temperatures",
            status: .init(text: "Awaiting sample", emphasis: .neutral)
        )
    ])
    .padding()
}
