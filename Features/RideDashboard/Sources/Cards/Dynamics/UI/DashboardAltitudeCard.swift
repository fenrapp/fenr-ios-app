import DesignSystem
import SwiftUI

struct DashboardAltitudeCard: View {
    let state: DashboardAltitudeViewData
    let reduceMotion: Bool

    var body: some View {
        DashboardSquareCardSurface {
            VStack(alignment: .leading, spacing: DesignSpace.small) {
                header
                HStack(spacing: DesignSpace.medium) {
                    DashboardAltitudeScale(ticks: state.ticks, reduceMotion: reduceMotion)
                        .frame(width: Constants.scaleWidth)
                        .opacity(state.isAvailable ? 1 : Constants.unavailableOpacity)
                    VStack(alignment: .leading, spacing: DesignSpace.large) {
                        currentAltitude
                            .frame(maxHeight: .infinity)
                        extremes
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .layoutPriority(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack {
            Text(.rideDashboardAltitudeTitle)
                .foregroundStyle(DesignColor.informational)
            Spacer(minLength: DesignSpace.extraSmall)
            Text(state.isAvailable ? .rideDashboardAltitudeSource : .rideDashboardAltitudeWaiting)
                .foregroundStyle(DesignColor.secondaryText)
        }
        .font(.caption2.weight(.bold))
    }

    private var currentAltitude: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraSmall) {
            Text(verbatim: state.valueText)
                .font(.system(size: Constants.valueFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(Constants.minimumValueScale)
                .lineLimit(1)
                .layoutPriority(1)
            Text(verbatim: state.unitText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
        }
    }

    private var extremes: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            Text(.rideDashboardAltitudeTrip)
                .font(.caption2)
                .foregroundStyle(DesignColor.secondaryText)
            HStack(alignment: .top, spacing: DesignSpace.small) {
                extreme(title: .rideDashboardAltitudeMinimum, value: state.minimumText)
                extreme(title: .rideDashboardAltitudeMaximum, value: state.maximumText)
            }
        }
        .padding(.bottom, DesignSpace.small)
    }

    private func extreme(title: LocalizedStringResource, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(verbatim: value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumValueScale)
            Text(title)
                .font(.caption2)
                .foregroundStyle(DesignColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value + " " + state.unitText)
    }

    private enum Constants {
        static let scaleWidth: CGFloat = 72
        static let valueFontSize: CGFloat = 58
        static let minimumValueScale = 0.5
        static let unavailableOpacity = 0.3
    }
}
