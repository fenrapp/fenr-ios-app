import DesignSystem
import SwiftUI

struct DashboardDynamicsAngleGauge: View {
    let status: DashboardRideDynamicsViewData.Status
    let angleDegrees: Double
    let maximumAngleDegrees: Double
    let vehiclePerspective: VehiclePerspective
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignColor.elevatedSurface,
                                DesignColor.groupedSurface.opacity(Constants.ambientEdgeOpacity)
                            ],
                            center: .center,
                            startRadius: .zero,
                            endRadius: side / 2
                        )
                    )
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignColor.informational.opacity(Constants.ringAccentOpacity),
                                DesignColor.border,
                                DesignColor.informational.opacity(Constants.ringAccentOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: Constants.ringWidth
                    )
                Circle()
                    .inset(by: Constants.innerRingInset)
                    .stroke(DesignColor.primaryText.opacity(Constants.innerRingOpacity), lineWidth: 1)

                ticks
                zeroMarker
                    .offset(y: -side / 2 + Constants.zeroMarkerInset)
                centerContent
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var displayAngle: Double {
        scale.clamped(angleDegrees)
    }

    private var scale: DashboardDynamicsAngleScale {
        .init(maximumAngleDegrees: maximumAngleDegrees)
    }

    private var ticks: some View {
        ForEach(0 ..< Constants.tickCount, id: \.self) { index in
            let progress = Double(index) / Double(Constants.tickCount - 1)
            let value = -maximumAngleDegrees + progress * maximumAngleDegrees * 2
            let rotation = -Constants.arcDegrees / 2 + progress * Constants.arcDegrees
            let isMajor = index.isMultiple(of: Constants.majorTickInterval)
            Capsule()
                .fill(tickColor(for: value))
                .frame(
                    width: isMajor ? Constants.majorTickWidth : Constants.minorTickWidth,
                    height: isMajor ? Constants.majorTickHeight : Constants.minorTickHeight
                )
                .offset(y: -Constants.tickOffset)
                .rotationEffect(.degrees(rotation))
        }
    }

    private var zeroMarker: some View {
        Image(systemName: "triangle.fill")
            .font(.system(size: Constants.zeroMarkerSize, weight: .bold))
            .foregroundStyle(DesignColor.informational)
            .shadow(
                color: DesignColor.informational.opacity(Constants.markerShadowOpacity),
                radius: Constants.markerShadowRadius
            )
    }

    @ViewBuilder
    private var centerContent: some View {
        switch status {
        case .calibrating:
            waitingContent(message: "CALIBRATING")
        case .zeroing:
            waitingContent(message: "HOLD STILL")
        case .unavailable:
            unavailableContent(message: "IMU UNAVAILABLE")
        case .signalLost:
            unavailableContent(message: "SIGNAL LOST")
        case .live:
            liveContent
        }
    }

    private var liveContent: some View {
        motorcycle
    }

    private func waitingContent(message: String) -> some View {
        VStack(spacing: Constants.calibrationSpacing) {
            vehicleSymbol
                .frame(width: Constants.calibrationVehicleWidth, height: Constants.calibrationVehicleHeight)
                .foregroundStyle(DesignColor.secondaryText)
            Text(message)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
        }
    }

    private func unavailableContent(message: String) -> some View {
        VStack(spacing: Constants.calibrationSpacing) {
            Image(systemName: "gyroscope")
                .font(.system(size: Constants.unavailableIconSize, weight: .light))
            Text(message)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(DesignColor.secondaryText)
    }

    private var motorcycle: some View {
        vehicleSymbol
            .frame(width: vehiclePerspective.size.width, height: vehiclePerspective.size.height)
            .foregroundStyle(DesignColor.primaryText)
            .rotationEffect(.degrees(displayAngle))
            .animation(
                reduceMotion ? nil : .snappy(duration: Constants.animationDuration),
                value: displayAngle
            )
    }

    @ViewBuilder
    private var vehicleSymbol: some View {
        switch vehiclePerspective {
        case .rear:
            DashboardRearMotorcycleSymbol()
        case .side:
            DashboardSideMotorcycleSymbol()
        }
    }

    private func tickColor(for value: Double) -> Color {
        guard status == .live else {
            return DesignColor.secondaryText.opacity(Constants.inactiveTickOpacity)
        }
        let tolerance = maximumAngleDegrees / Double(Constants.tickCount)
        let isZero = abs(value) <= tolerance
        let isActive = scale.isActiveTick(value, for: displayAngle, tolerance: tolerance)
        return isZero || isActive
            ? DesignColor.informational
            : DesignColor.secondaryText.opacity(Constants.inactiveTickOpacity)
    }

    private enum Constants {
        static let ringWidth: CGFloat = 1
        static let ringAccentOpacity = 0.55
        static let innerRingInset: CGFloat = 3
        static let innerRingOpacity = 0.06
        static let ambientEdgeOpacity = 0.2
        static let tickCount = 25
        static let majorTickInterval = 4
        static let arcDegrees = 240.0
        static let majorTickWidth: CGFloat = 2
        static let majorTickHeight: CGFloat = 10
        static let minorTickWidth: CGFloat = 1
        static let minorTickHeight: CGFloat = 6
        static let tickOffset: CGFloat = 82
        static let zeroMarkerSize: CGFloat = 7
        static let zeroMarkerInset: CGFloat = 7
        static let markerShadowOpacity = 0.55
        static let markerShadowRadius: CGFloat = 3
        static let calibrationSpacing: CGFloat = 5
        static let calibrationVehicleWidth: CGFloat = 46
        static let calibrationVehicleHeight: CGFloat = 30
        static let unavailableIconSize: CGFloat = 28
        static let animationDuration = 0.2
        static let inactiveTickOpacity = 0.28
    }

    enum VehiclePerspective {
        case rear
        case side

        var size: CGSize {
            switch self {
            case .rear: CGSize(width: 50, height: 58)
            case .side: CGSize(width: 62, height: 40)
            }
        }
    }
}

private struct DashboardRearMotorcycleSymbol: View {
    var body: some View {
        Canvas { context, size in
            let lineWidth = max(size.width * Constants.lineWidthRatio, Constants.minimumLineWidth)
            var handlebar = Path()
            handlebar.move(to: .init(x: size.width * 0.12, y: size.height * 0.24))
            handlebar.addLine(to: .init(x: size.width * 0.32, y: size.height * 0.16))
            handlebar.addLine(to: .init(x: size.width * 0.68, y: size.height * 0.16))
            handlebar.addLine(to: .init(x: size.width * 0.88, y: size.height * 0.24))
            context.stroke(
                handlebar,
                with: .foreground,
                style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            var body = Path()
            body.move(to: .init(x: size.width * 0.31, y: size.height * 0.29))
            body.addLine(to: .init(x: size.width * 0.69, y: size.height * 0.29))
            body.addLine(to: .init(x: size.width * 0.62, y: size.height * 0.59))
            body.addLine(to: .init(x: size.width * 0.38, y: size.height * 0.59))
            body.closeSubpath()
            context.stroke(
                body,
                with: .foreground,
                style: .init(lineWidth: lineWidth, lineJoin: .round)
            )

            for centerX in [0.14, 0.86] {
                context.stroke(
                    Path(ellipseIn: .init(
                        x: size.width * centerX - lineWidth,
                        y: size.height * 0.22 - lineWidth,
                        width: lineWidth * 2,
                        height: lineWidth * 2
                    )),
                    with: .foreground,
                    lineWidth: lineWidth * 0.7
                )
            }

            var suspension = Path()
            suspension.move(to: .init(x: size.width * 0.39, y: size.height * 0.53))
            suspension.addLine(to: .init(x: size.width * 0.45, y: size.height * 0.89))
            suspension.move(to: .init(x: size.width * 0.61, y: size.height * 0.53))
            suspension.addLine(to: .init(x: size.width * 0.55, y: size.height * 0.89))
            context.stroke(suspension, with: .foreground, lineWidth: lineWidth * 0.7)

            context.stroke(
                Path(roundedRect: .init(
                    x: size.width * 0.43,
                    y: size.height * 0.54,
                    width: size.width * 0.14,
                    height: size.height * 0.43
                ), cornerRadius: size.width * 0.07),
                with: .foreground,
                lineWidth: lineWidth
            )
            context.fill(
                Path(roundedRect: .init(
                    x: size.width * 0.43,
                    y: size.height * 0.36,
                    width: size.width * 0.14,
                    height: size.height * 0.08
                ), cornerRadius: lineWidth / 2),
                with: .color(DesignColor.informational)
            )
        }
        .accessibilityHidden(true)
    }

    private enum Constants {
        static let lineWidthRatio = 0.07
        static let minimumLineWidth: CGFloat = 2
    }
}

private struct DashboardSideMotorcycleSymbol: View {
    var body: some View {
        Canvas { context, size in
            let lineWidth = max(size.height * Constants.lineWidthRatio, Constants.minimumLineWidth)
            let rearWheelCenter = CGPoint(x: size.width * 0.2, y: size.height * 0.74)
            let frontWheelCenter = CGPoint(x: size.width * 0.8, y: size.height * 0.74)
            let wheelRadius = size.height * Constants.wheelRadiusRatio

            for center in [rearWheelCenter, frontWheelCenter] {
                context.stroke(
                    Path(ellipseIn: .init(
                        x: center.x - wheelRadius,
                        y: center.y - wheelRadius,
                        width: wheelRadius * 2,
                        height: wheelRadius * 2
                    )),
                    with: .foreground,
                    lineWidth: lineWidth
                )
            }

            var frame = Path()
            frame.move(to: rearWheelCenter)
            frame.addLine(to: .init(x: size.width * 0.43, y: size.height * 0.38))
            frame.addLine(to: .init(x: size.width * 0.61, y: size.height * 0.7))
            frame.addLine(to: rearWheelCenter)
            frame.move(to: .init(x: size.width * 0.43, y: size.height * 0.38))
            frame.addLine(to: .init(x: size.width * 0.68, y: size.height * 0.31))
            frame.addLine(to: frontWheelCenter)
            frame.move(to: .init(x: size.width * 0.66, y: size.height * 0.32))
            frame.addLine(to: .init(x: size.width * 0.72, y: size.height * 0.18))
            frame.addLine(to: .init(x: size.width * 0.81, y: size.height * 0.17))
            context.stroke(
                frame,
                with: .foreground,
                style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            context.fill(
                Path(roundedRect: .init(
                    x: size.width * 0.31,
                    y: size.height * 0.27,
                    width: size.width * 0.3,
                    height: size.height * 0.12
                ), cornerRadius: lineWidth),
                with: .foreground
            )
            context.fill(
                Path(roundedRect: .init(
                    x: size.width * 0.42,
                    y: size.height * 0.43,
                    width: size.width * 0.2,
                    height: size.height * 0.23
                ), cornerRadius: lineWidth),
                with: .foreground
            )
        }
        .accessibilityHidden(true)
    }

    private enum Constants {
        static let lineWidthRatio = 0.07
        static let minimumLineWidth: CGFloat = 2
        static let wheelRadiusRatio = 0.18
    }
}

struct DashboardDynamicsAngleScale {
    let maximumAngleDegrees: Double

    func clamped(_ angleDegrees: Double) -> Double {
        let limit = max(abs(maximumAngleDegrees), .leastNonzeroMagnitude)
        return min(max(angleDegrees, -limit), limit)
    }

    func isActiveTick(_ value: Double, for angleDegrees: Double, tolerance: Double) -> Bool {
        let angle = clamped(angleDegrees)
        return angle >= .zero
            ? value >= -tolerance && value <= angle + tolerance
            : value <= tolerance && value >= angle - tolerance
    }
}
