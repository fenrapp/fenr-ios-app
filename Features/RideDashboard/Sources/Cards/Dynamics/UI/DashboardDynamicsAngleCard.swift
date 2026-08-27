import DesignSystem
import SwiftUI

struct DashboardDynamicsAngleCard: View {
    let title: String
    let status: DashboardRideDynamicsViewData.Status
    let angleDegrees: Double
    let maximumAngleDegrees: Double
    let vehiclePerspective: DashboardDynamicsAngleGauge.VehiclePerspective
    let angleText: String
    let directionText: String
    let maximums: [Maximum]
    let canCalibrate: Bool
    let calibrate: () -> Void

    var body: some View {
        DashboardTripCardSurface {
            VStack(spacing: Constants.spacing) {
                DashboardTripCardHeader(title: title, subtitle: status.rawValue) {
                    zeroButton
                }
                HStack(spacing: Constants.heroSpacing) {
                    DashboardDynamicsAngleGauge(
                        angleDegrees: angleDegrees,
                        maximumAngleDegrees: maximumAngleDegrees,
                        vehiclePerspective: vehiclePerspective
                    )
                    angleReadout
                }
                HStack(spacing: DesignSpace.large) {
                    ForEach(maximums) { maximum in
                        maximumMetric(maximum)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(angleText), \(directionText)")
    }

    private var zeroButton: some View {
        Button(action: calibrate) {
            Label("ZERO", systemImage: "scope")
                .font(.caption2.weight(.bold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(DesignColor.informational)
        .disabled(!canCalibrate)
        .accessibilityHint("Calibrates the current level position")
    }

    private var angleReadout: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(angleText)
                .font(.system(size: Constants.heroFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
            Text(directionText)
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignColor.informational)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func maximumMetric(_ maximum: Maximum) -> some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(maximum.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
            Text(maximum.value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    struct Maximum: Identifiable {
        let label: String
        let value: String

        var id: String { label }
    }

    private enum Constants {
        static let spacing: CGFloat = 8
        static let heroSpacing: CGFloat = 14
        static let heroFontSize: CGFloat = 50
    }
}
