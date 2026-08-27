import DesignSystem
import SwiftUI

struct DashboardDynamicsAngleGauge: View {
    let angleDegrees: Double
    let maximumAngleDegrees: Double
    let vehiclePerspective: VehiclePerspective

    var body: some View {
        ZStack {
            Circle()
                .trim(from: Constants.startTrim, to: Constants.endTrim)
                .stroke(DesignColor.border, style: .init(lineWidth: Constants.trackWidth, lineCap: .round))
                .rotationEffect(.degrees(Constants.trackRotation))

            ForEach(Constants.tickAngles, id: \.self) { value in
                Capsule()
                    .fill(tickColor(for: value))
                    .frame(width: Constants.tickWidth, height: Constants.tickHeight)
                    .offset(y: -Constants.tickOffset)
                    .rotationEffect(.degrees(value))
            }

            Image(systemName: "motorcycle")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(
                    width: vehiclePerspective.size.width,
                    height: vehiclePerspective.size.height
                )
                .foregroundStyle(DesignColor.primaryText)
                .rotationEffect(.degrees(displayAngle))
                .animation(.snappy(duration: Constants.animationDuration), value: displayAngle)
        }
        .frame(width: Constants.size, height: Constants.size)
        .accessibilityHidden(true)
    }

    private var displayAngle: Double {
        min(max(angleDegrees, -maximumAngleDegrees), maximumAngleDegrees)
    }

    private func tickColor(for value: Double) -> Color {
        abs(value) <= abs(angleDegrees)
            ? DesignColor.informational
            : DesignColor.secondaryText.opacity(Constants.inactiveTickOpacity)
    }

    private enum Constants {
        static let size: CGFloat = 150
        static let trackWidth: CGFloat = 2
        static let tickWidth: CGFloat = 2
        static let tickHeight: CGFloat = 9
        static let tickOffset: CGFloat = 67
        static let startTrim = 0.08
        static let endTrim = 0.92
        static let trackRotation = 104.0
        static let animationDuration = 0.18
        static let inactiveTickOpacity = 0.35
        static let tickAngles = Array(stride(from: -60.0, through: 60.0, by: 10))
    }

    enum VehiclePerspective {
        case front
        case side

        var size: CGSize {
            switch self {
            case .front: CGSize(width: 50, height: 58)
            case .side: CGSize(width: 70, height: 46)
            }
        }
    }
}
