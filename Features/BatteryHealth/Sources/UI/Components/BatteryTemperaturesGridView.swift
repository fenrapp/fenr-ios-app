import DesignSystem
import SwiftUI

struct BatteryTemperaturesGridView: View {
    let temperatures: [BatteryTemperatureViewData]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Constants.rowSpacing) {
            ForEach(temperatures) { temperature in
                HStack {
                    Text("Sensor \(temperature.position)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(temperature.value)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                }
                .font(.callout)
                .padding(Constants.itemPadding)
                .background(
                    DesignColor.elevatedSurface,
                    in: RoundedRectangle(cornerRadius: Constants.cornerRadius)
                )
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Constants.columnSpacing), count: Constants.columnCount)
    }

    private enum Constants {
        static let columnCount = 2
        static let columnSpacing = DesignSpace.extraSmall
        static let rowSpacing = DesignSpace.extraSmall
        static let itemPadding = DesignSpace.small
        static let cornerRadius = DesignRadius.small
    }
}

#Preview("Temperatures") {
    BatteryTemperaturesGridView(temperatures: [
        .init(position: 1, value: "28.1 °C"),
        .init(position: 2, value: "28.4 °C")
    ])
    .padding()
}
