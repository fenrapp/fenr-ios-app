import DesignSystem
import SwiftUI

struct DashboardRearMotorcycleSymbol: View {
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
            context.stroke(body, with: .foreground, style: .init(lineWidth: lineWidth, lineJoin: .round))

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

struct DashboardSideMotorcycleSymbol: View {
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
