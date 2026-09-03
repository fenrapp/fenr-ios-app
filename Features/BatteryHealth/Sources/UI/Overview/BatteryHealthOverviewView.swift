import DesignSystem
import SwiftUI

struct BatteryHealthOverviewView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: BatteryHealthOverviewViewData
    let onNavigate: (BatteryHealthDestination) -> Void

    @ScaledMetric(relativeTo: .headline) private var statusIconSize = Constants.statusIconSize

    var body: some View {
        List {
            if !state.banners.isEmpty {
                Section(BatteryHealthText.attention) {
                    ForEach(state.banners) { banner in
                        BatteryHealthBannerView(banner: banner)
                    }
                }
            }

            Section {
                healthSummary
                .accessibilityElement(children: .combine)
            }

            Section(BatteryHealthText.liveSummary) {
                BatteryHealthMetricRows(metrics: state.summaryMetrics)
            }

            Section(BatteryHealthText.details) {
                destinationLink(
                    .cells,
                    subtitle: String(localized: .batteryHealthOverviewSubtitleCells),
                    systemImage: "battery.75percent",
                    tint: DesignColor.positive
                )
                destinationLink(
                    .thermal,
                    subtitle: String(localized: .batteryHealthOverviewSubtitleThermal),
                    systemImage: "thermometer.medium",
                    tint: DesignColor.warning
                )
                destinationLink(
                    .charging,
                    subtitle: String(localized: .batteryHealthOverviewSubtitleCharging),
                    systemImage: "bolt.fill",
                    tint: .blue
                )
                destinationLink(
                    .rawData,
                    subtitle: String(localized: .batteryHealthOverviewSubtitleRawData),
                    systemImage: "doc.text.magnifyingglass",
                    tint: .indigo
                )
            }
        }
    }

    @ViewBuilder private var healthSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignSpace.small) {
                healthIndicator
                healthDescription
            }
        } else {
            HStack(spacing: DesignSpace.medium) {
                healthIndicator
                healthDescription
            }
        }
    }

    private var healthDescription: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(state.status.text)
                .font(.title2.bold())
            Text(state.statusDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var healthIndicator: some View {
        if let progress = state.stateOfHealthProgress, let sohMetric = state.stateOfHealthMetric {
            ProgressRing(progress: progress, color: statusColor, lineWidth: Constants.ringLineWidth) {
                Text(sohMetric.value)
                    .font(.headline.monospacedDigit())
            }
            .frame(width: statusIconSize, height: statusIconSize)
            .accessibilityLabel(sohMetric.title)
            .accessibilityValue(sohMetric.value)
        } else {
            Image(systemName: statusImage)
                .font(.title)
                .foregroundStyle(statusColor)
                .frame(width: statusIconSize, height: statusIconSize)
        }
    }

    private func destinationLink(
        _ destination: BatteryHealthDestination,
        subtitle: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        ListNavigationRow(
            title: destination.title,
            subtitle: subtitle,
            systemImage: systemImage,
            tint: tint,
            action: { onNavigate(destination) }
        )
    }

    private var statusImage: String {
        switch state.status {
        case .collecting: "waveform.path.ecg"
        case .healthy: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        case .unavailable: "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch state.status.emphasis {
        case .neutral: .secondary
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private enum Constants {
        static let statusIconSize: CGFloat = 52
        static let ringLineWidth: CGFloat = 6
    }
}
