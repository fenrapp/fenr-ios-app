import DesignSystem
import SwiftUI

struct DashboardPowerModeColumn: View {
    let state: DashboardPowerModeViewData

    var body: some View {
        VStack(spacing: DesignSpace.small) {
            Spacer(minLength: .zero)
            Text("MODE")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(state.map)
                .font(.system(size: 58, weight: .medium, design: .rounded))
                .foregroundStyle(DesignColor.positive)
                .lineLimit(1)
            readout(label: "POWER", value: state.horsepower)
            readout(label: "REGEN", value: state.regenerativeBraking)
            readout(label: "TC POWER", value: state.powerTraction)
            readout(label: "TC REGEN", value: state.brakingTraction)
            Text(state.tierBadge)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Spacer(minLength: .zero)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func readout(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

#Preview("Standard") {
    DashboardPowerModeColumn(state: .init(map: "5", horsepower: "60 HP"))
        .frame(width: 220, height: 380)
}

#Preview("Alpha") {
    DashboardPowerModeColumn(state: .init(
        map: "5",
        horsepower: "80 HP",
        regenerativeBraking: "40%",
        powerTraction: "35%",
        brakingTraction: "12.5%",
        tierBadge: "ALPHA · 80 MAX"
    ))
    .frame(width: 220, height: 380)
}

#Preview("Pending verification") {
    DashboardPowerModeColumn(state: .init(map: "3", horsepower: "50 HP"))
        .frame(width: 220, height: 380)
}

#Preview("Partial data") {
    DashboardPowerModeColumn(state: .init(map: "2", horsepower: "--", powerTraction: "20%"))
        .frame(width: 220, height: 380)
}
