import DesignSystem
import SwiftUI

struct BatteryCellsGridView: View {
    let cells: [BatteryCellViewData]

    @State private var selectedCell: BatteryCellViewData?

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            LazyVGrid(columns: columns, spacing: Constants.gridSpacing) {
                ForEach(cells) { cell in
                    Button {
                        selectedCell = selectedCell?.id == cell.id ? nil : cell
                    } label: {
                        Text(verbatim: "\(cell.position)")
                            .font(.system(size: Constants.positionFontSize, design: .monospaced).weight(.semibold))
                            .foregroundStyle(foregroundColor(for: cell))
                            .frame(maxWidth: .infinity, minHeight: Constants.tileHeight)
                            .background(
                                tileColor(for: cell),
                                in: RoundedRectangle(cornerRadius: Constants.tileCornerRadius)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: cell))
                }
            }

            if let selectedCell {
                selectedCellDetail(selectedCell)
            }

            legend
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Constants.gridSpacing),
            count: Constants.columnCount
        )
    }

    private var legend: some View {
        HStack(spacing: Constants.legendSpacing) {
            legendItem(title: String(localized: .batteryHealthCellConditionLow), color: color(for: .belowAverage))
            legendItem(title: String(localized: .batteryHealthCellConditionNormal), color: color(for: .normal))
            legendItem(title: String(localized: .batteryHealthCellConditionHigh), color: color(for: .aboveAverage))
            legendItem(title: String(localized: .batteryHealthCellConditionCritical), color: color(for: .critical))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func selectedCellDetail(_ cell: BatteryCellViewData) -> some View {
        HStack(spacing: Constants.detailSpacing) {
            Text(String(localized: .batteryHealthCellPosition(cell.position)))
                .font(.subheadline.weight(.semibold))
            Text(cell.voltage)
            Text(cell.deviation)
                .foregroundStyle(.secondary)
            if cell.isBalancing {
                Text(String(localized: .batteryHealthCellBalancing))
                    .foregroundStyle(.orange)
            }
        }
        .font(.subheadline.monospacedDigit())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.detailPadding)
        .background(
            DesignColor.elevatedSurface,
            in: RoundedRectangle(cornerRadius: Constants.detailCornerRadius)
        )
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: Constants.legendItemSpacing) {
            Circle()
                .fill(color)
                .frame(width: Constants.legendMarkerSize, height: Constants.legendMarkerSize)
            Text(title)
        }
    }

    private func tileColor(for cell: BatteryCellViewData) -> Color {
        if cell.isBalancing {
            return Constants.balancingColor
        }
        return color(for: cell.condition)
    }

    private func foregroundColor(for cell: BatteryCellViewData) -> Color {
        cell.condition == .critical ? .white : .primary
    }

    private func color(for condition: BatteryCellCondition) -> Color {
        switch condition {
        case .normal:
            Color(.tertiarySystemFill)
        case .belowAverage:
            Constants.lowCellColor
        case .aboveAverage:
            Constants.highCellColor
        case .critical:
            Constants.criticalCellColor
        }
    }

    private func accessibilityLabel(for cell: BatteryCellViewData) -> String {
        if cell.isBalancing {
            return String(
                localized: .batteryHealthCellAccessibilityBalancing(
                    cell.position,
                    cell.voltage,
                    cell.deviation
                )
            )
        }
        return String(
            localized: .batteryHealthCellAccessibility(cell.position, cell.voltage, cell.deviation)
        )
    }

    private enum Constants {
        static let columnCount = 10
        static let gridSpacing = DesignSpace.extraExtraSmall
        static let sectionSpacing = DesignSpace.small
        static let tileHeight: CGFloat = 28
        static let tileCornerRadius: CGFloat = 5
        static let positionFontSize: CGFloat = 11
        static let detailSpacing = DesignSpace.extraSmall
        static let detailPadding = DesignSpace.small
        static let detailCornerRadius = DesignRadius.small
        static let legendSpacing = DesignSpace.small
        static let legendItemSpacing = DesignSpace.extraExtraSmall
        static let legendMarkerSize = DesignSpace.extraSmall
        static let lowCellColor = DesignColor.warning.opacity(0.35)
        static let highCellColor = Color.cyan.opacity(0.35)
        static let criticalCellColor = DesignColor.critical.opacity(0.65)
        static let balancingColor = DesignColor.warning.opacity(0.5)
    }
}

#Preview("Cells") {
    BatteryCellsGridView(cells: [
        .init(
            position: 1,
            voltage: "3.8446 V",
            deviation: "+4 mV",
            condition: .aboveAverage,
            isBalancing: false,
            isMinimum: false,
            isMaximum: true
        ),
        .init(
            position: 2,
            voltage: "3.8286 V",
            deviation: "-12 mV",
            condition: .belowAverage,
            isBalancing: true,
            isMinimum: true,
            isMaximum: false
        )
    ])
    .padding()
}
