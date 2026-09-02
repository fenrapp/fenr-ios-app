import DesignSystem
import SwiftUI

struct DashboardCourseCard: View {
    let state: DashboardRideDynamicsViewData
    let reduceMotion: Bool

    var body: some View {
        DashboardSquareCardSurface {
            VStack(spacing: Constants.spacing) {
                HStack(spacing: DesignSpace.extraSmall) {
                    Text(.rideDashboardDynamicsCourseTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DesignColor.informational)
                    Spacer()
                    Circle()
                        .fill(state.isHeadingAvailable ? DesignColor.informational : DesignColor.secondaryText)
                        .frame(width: Constants.sourceDotSize, height: Constants.sourceDotSize)
                    Text(state.headingSourceText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DesignColor.secondaryText)
                }
                DashboardCompassDial(
                    headingDegrees: state.headingDegrees,
                    isHeadingAvailable: state.isHeadingAvailable,
                    cardinalDirectionText: state.cardinalDirectionText,
                    headingText: state.headingText,
                    altitudeText: state.altitudeText,
                    reduceMotion: reduceMotion
                )
                .layoutPriority(1)
                coordinateFooter
            }
            // This is a fixed-size instrument cluster. Capping its visual type prevents
            // the dial from collapsing while the combined accessibility label still
            // exposes every value at the user's preferred reading size.
            .dynamicTypeSize(...DynamicTypeSize.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var coordinateFooter: some View {
        HStack(spacing: Constants.coordinateSpacing) {
            Text(state.latitudeText ?? "")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(state.longitudeText ?? "")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2.weight(.medium))
        .monospacedDigit()
        .foregroundStyle(DesignColor.secondaryText)
        .frame(height: Constants.coordinateFooterHeight)
        .opacity(hasCoordinates ? 1 : 0)
        .accessibilityHidden(!hasCoordinates)
    }

    private var hasCoordinates: Bool {
        state.latitudeText != nil && state.longitudeText != nil
    }

    private var accessibilityText: String {
        var components = [
            rideDashboardLocalized(.rideDashboardDynamicsCourseAccessibility(
                state.cardinalDirectionText,
                state.headingText,
                state.headingSourceText
            ))
        ]
        if let altitude = state.altitudeText {
            components.append(rideDashboardLocalized(.rideDashboardDynamicsAltitudeAccessibility(altitude)))
        }
        if let latitude = state.latitudeText,
           let longitude = state.longitudeText {
            components.append(rideDashboardLocalized(
                .rideDashboardDynamicsCoordinatesAccessibility(latitude, longitude)
            ))
        }
        return components.joined(separator: ", ")
    }

    private enum Constants {
        static let spacing: CGFloat = 5
        static let sourceDotSize: CGFloat = 5
        static let coordinateSpacing: CGFloat = 8
        static let coordinateFooterHeight: CGFloat = 14
    }
}
