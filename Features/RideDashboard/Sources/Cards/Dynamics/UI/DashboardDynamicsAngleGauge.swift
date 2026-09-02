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
            waitingContent(message: rideDashboardLocalized(.rideDashboardDynamicsStatusCalibrating))
        case .zeroing:
            waitingContent(message: rideDashboardLocalized(.rideDashboardDynamicsStatusZeroing))
        case .unavailable:
            unavailableContent(message: rideDashboardLocalized(.rideDashboardDynamicsGaugeImuUnavailable))
        case .signalLost:
            unavailableContent(message: rideDashboardLocalized(.rideDashboardDynamicsStatusSignalLost))
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
