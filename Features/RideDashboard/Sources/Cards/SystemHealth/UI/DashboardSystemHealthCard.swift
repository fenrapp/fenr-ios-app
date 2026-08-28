import DesignSystem
import SwiftUI

struct DashboardSystemHealthCard: View {
    let state: DashboardSystemHealthViewData

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(spacing: Constants.spacing) {
                DashboardSystemHealthHeader(title: "SYSTEM HEALTH", state: state)
                healthRing
                    .layoutPriority(1)
                metrics
                if showsStatusBanner {
                    statusBanner
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var healthRing: some View {
        ZStack {
            Circle()
                .stroke(DesignColor.inactive, lineWidth: Constants.ringLineWidth)
            Circle()
                .trim(from: .zero, to: state.stateOfHealthProgress)
                .stroke(
                    statusColor.gradient,
                    style: StrokeStyle(lineWidth: Constants.ringLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: DesignSpace.extraExtraSmall) {
                Text(state.stateOfHealthText)
                    .font(.system(size: Constants.healthFontSize, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Text("BATTERY HEALTH")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DesignColor.secondaryText)
                Text(state.statusText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
            }
        }
        .frame(maxHeight: Constants.maximumRingSize)
        .aspectRatio(1, contentMode: .fit)
    }

    private var metrics: some View {
        Grid(horizontalSpacing: DesignSpace.small, verticalSpacing: DesignSpace.extraSmall) {
            GridRow {
                metric(title: "CELL DELTA", value: state.cellDeltaText)
                metric(title: "DC BUS", value: state.dcBusVoltageText)
            }
            GridRow {
                metric(title: "BATTERY", value: state.batteryTemperatureText)
                metric(title: "INVERTER", value: state.inverterTemperatureText)
            }
        }
    }

    private var statusBanner: some View {
        Text(state.statusDetail)
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .minimumScaleFactor(Constants.minimumTextScale)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSpace.extraExtraSmall)
            .background(statusColor.opacity(Constants.bannerOpacity), in: Capsule())
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: DesignSpace.extraExtraSmall) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumTextScale)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusColor: Color {
        DashboardSystemHealthStyle.color(for: state.status)
    }

    private var showsStatusBanner: Bool {
        switch state.status {
        case .healthy, .scanning: false
        case .lowBattery, .attention, .critical, .unavailable: true
        }
    }

    private var accessibilityText: String {
        [
            "System health \(state.statusText)",
            "battery health \(state.stateOfHealthText)",
            "cell delta \(state.cellDeltaText)",
            "DC bus \(state.dcBusVoltageText)",
            "battery temperature \(state.batteryTemperatureText)",
            "inverter temperature \(state.inverterTemperatureText)",
            state.statusDetail
        ].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private enum Constants {
        static let spacing: CGFloat = 6
        static let ringLineWidth: CGFloat = 10
        static let healthFontSize: CGFloat = 34
        static let maximumRingSize: CGFloat = 165
        static let bannerOpacity = 0.12
        static let minimumTextScale = 0.75
    }
}
