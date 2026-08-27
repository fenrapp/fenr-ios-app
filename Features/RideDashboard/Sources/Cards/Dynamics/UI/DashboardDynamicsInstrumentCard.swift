import DesignSystem
import SwiftUI

struct DashboardDynamicsInstrumentCard: View {
    let title: String
    let status: DashboardRideDynamicsViewData.Status
    let angleDegrees: Double
    let maximumAngleDegrees: Double
    let vehiclePerspective: DashboardDynamicsAngleGauge.VehiclePerspective
    let angleText: String
    let directionText: String
    let maximums: [Maximum]
    let canCalibrate: Bool
    let reduceMotion: Bool
    let calibrate: () -> Void

    var body: some View {
        DashboardSquareCardSurface {
            VStack(spacing: Constants.spacing) {
                header
                DashboardDynamicsAngleGauge(
                    status: status,
                    angleDegrees: angleDegrees,
                    maximumAngleDegrees: maximumAngleDegrees,
                    vehiclePerspective: vehiclePerspective,
                    canCalibrate: canCalibrate,
                    reduceMotion: reduceMotion,
                    calibrate: calibrate
                )
                .layoutPriority(1)
                currentMetric
                maximumMetrics
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var header: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.informational)
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: Constants.statusDotSize, height: Constants.statusDotSize)
            Text(status.rawValue)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
            if status != .calibrationRequired {
                zeroButton
            }
        }
    }

    private var zeroButton: some View {
        Button(action: calibrate) {
            Image(systemName: "scope")
                .font(.caption.weight(.bold))
                .frame(width: Constants.zeroButtonSize, height: Constants.zeroButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(DesignColor.informational)
        .disabled(!canCalibrate)
        .opacity(canCalibrate ? 1 : Constants.disabledOpacity)
        .accessibilityLabel("Zero \(title.lowercased())")
        .accessibilityHint("Calibrates the current level position")
    }

    private var maximumMetrics: some View {
        HStack(spacing: DesignSpace.large) {
            ForEach(maximums) { maximum in
                maximumMetric(maximum)
            }
        }
        .frame(height: Constants.maximumMetricsHeight)
    }

    private var currentMetric: some View {
        VStack(spacing: DesignSpace.extraExtraSmall) {
            Text(angleText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            Text(directionText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.informational)
        }
        .frame(height: Constants.currentMetricHeight)
    }

    private func maximumMetric(_ maximum: Maximum) -> some View {
        VStack(alignment: maximum.alignment, spacing: DesignSpace.extraExtraSmall) {
            Text(maximum.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumLabelScale)
            Text(maximum.value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: maximum.frameAlignment)
    }

    private var statusColor: Color {
        switch status {
        case .live: DesignColor.informational
        case .calibrationRequired: DesignColor.warning
        case .signalLost: DesignColor.critical
        case .unavailable: DesignColor.secondaryText
        }
    }

    private var accessibilityText: String {
        let maximumText = maximums.map { "\($0.label) \($0.value)" }.joined(separator: ", ")
        return "\(title), \(status.rawValue), \(angleText), \(directionText), \(maximumText)"
    }

    struct Maximum: Identifiable {
        let label: String
        let value: String
        let alignment: HorizontalAlignment
        let frameAlignment: Alignment

        var id: String { label }

        init(label: String, value: String, trailing: Bool = false) {
            self.label = label
            self.value = value
            alignment = trailing ? .trailing : .leading
            frameAlignment = trailing ? .trailing : .leading
        }
    }

    private enum Constants {
        static let spacing: CGFloat = 4
        static let statusDotSize: CGFloat = 5
        static let zeroButtonSize: CGFloat = 22
        static let currentMetricHeight: CGFloat = 28
        static let maximumMetricsHeight: CGFloat = 34
        static let minimumLabelScale = 0.8
        static let disabledOpacity = 0.35
    }
}
