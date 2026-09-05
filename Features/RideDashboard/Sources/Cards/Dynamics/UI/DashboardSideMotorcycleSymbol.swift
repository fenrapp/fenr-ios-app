import DesignSystem
import SwiftUI

struct DashboardSideMotorcycleSymbol: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(
                x: size.width / Artwork.viewBoxSize.width,
                y: size.height / Artwork.viewBoxSize.height
            )
            context.stroke(Artwork.rearWheel, with: .foreground, style: Artwork.rearWheelStroke)
            context.stroke(Artwork.frontWheel, with: .foreground, style: Artwork.frontWheelStroke)
            context.fill(Artwork.rearHub, with: .foreground)
            context.fill(Artwork.frontHub, with: .foreground)
            context.fill(Artwork.swingarm, with: .foreground)
            context.fill(Artwork.motorHousing, with: .foreground)
            context.blendMode = .destinationOut
            context.fill(Artwork.motorInset, with: .color(.white))
            context.blendMode = .normal
            context.fill(Artwork.rearFender, with: .foreground)
            context.fill(Artwork.seat, with: .foreground)
            context.fill(Artwork.bodyPanels, with: .foreground)
            context.fill(Artwork.bodyAccent, with: .color(DesignColor.informational))
            context.fill(Artwork.frontFork, with: .foreground)
            context.fill(Artwork.frontFender, with: .foreground)
            context.stroke(Artwork.handlebar, with: .foreground, style: Artwork.handlebarStroke)
            context.fill(Artwork.handguard, with: .foreground)
            context.fill(Artwork.frontPlate, with: .foreground)
        }
        .aspectRatio(Artwork.viewBoxSize.width / Artwork.viewBoxSize.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private enum Artwork {
        static let viewBoxSize = CGSize(width: 160, height: 112)

        static var rearWheel: Path {
            Path(ellipseIn: .init(x: 10, y: 62, width: 40, height: 40))
        }

        static let rearWheelStroke = StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round)

        static var frontWheel: Path {
            Path(ellipseIn: .init(x: 106, y: 60, width: 44, height: 44))
        }

        static let frontWheelStroke = StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round)

        static var rearHub: Path {
            Path(ellipseIn: .init(x: 27, y: 79, width: 6, height: 6))
        }

        static var frontHub: Path {
            Path(ellipseIn: .init(x: 125, y: 79, width: 6, height: 6))
        }

        static var swingarm: Path {
            Path { path in
                path.move(to: .init(x: 29, y: 79))
                path.addLine(to: .init(x: 62, y: 67))
                path.addLine(to: .init(x: 80, y: 66))
                path.addLine(to: .init(x: 76, y: 76))
                path.addLine(to: .init(x: 31, y: 85))
                path.closeSubpath()
            }
        }

        static var motorHousing: Path {
            Path { path in
                path.move(to: .init(x: 56, y: 52))
                path.addLine(to: .init(x: 86, y: 48))
                path.addLine(to: .init(x: 94, y: 56))
                path.addLine(to: .init(x: 85, y: 74))
                path.addLine(to: .init(x: 65, y: 74))
                path.addLine(to: .init(x: 55, y: 65))
                path.closeSubpath()
            }
        }

        static var motorInset: Path {
            Path { path in
                path.move(to: .init(x: 65, y: 57))
                path.addLine(to: .init(x: 83, y: 54))
                path.addLine(to: .init(x: 80, y: 67))
                path.addLine(to: .init(x: 65, y: 67))
                path.closeSubpath()
            }
        }

        static var rearFender: Path {
            Path { path in
                path.move(to: .init(x: 9, y: 38))
                path.addLine(to: .init(x: 28, y: 36))
                path.addLine(to: .init(x: 51, y: 39))
                path.addLine(to: .init(x: 55, y: 45))
                path.addLine(to: .init(x: 29, y: 45))
                path.closeSubpath()
            }
        }

        static var seat: Path {
            Path { path in
                path.move(to: .init(x: 28, y: 32))
                path.addLine(to: .init(x: 69, y: 33))
                path.addLine(to: .init(x: 85, y: 38))
                path.addLine(to: .init(x: 80, y: 43))
                path.addLine(to: .init(x: 48, y: 39))
                path.addLine(to: .init(x: 29, y: 39))
                path.closeSubpath()
            }
        }

        static var bodyPanels: Path {
            Path { path in
                path.move(to: .init(x: 48, y: 43))
                path.addLine(to: .init(x: 75, y: 40))
                path.addLine(to: .init(x: 89, y: 33))
                path.addLine(to: .init(x: 103, y: 36))
                path.addLine(to: .init(x: 99, y: 49))
                path.addLine(to: .init(x: 84, y: 57))
                path.addLine(to: .init(x: 65, y: 60))
                path.closeSubpath()
            }
        }

        static var bodyAccent: Path {
            Path { path in
                path.move(to: .init(x: 69, y: 45))
                path.addLine(to: .init(x: 91, y: 40))
                path.addLine(to: .init(x: 88, y: 46))
                path.addLine(to: .init(x: 72, y: 51))
                path.closeSubpath()
            }
        }

        static var frontFork: Path {
            Path { path in
                path.move(to: .init(x: 103, y: 31))
                path.addLine(to: .init(x: 109, y: 30))
                path.addLine(to: .init(x: 132, y: 83))
                path.addLine(to: .init(x: 126, y: 85))
                path.closeSubpath()
            }
        }

        static var frontFender: Path {
            Path { path in
                path.move(to: .init(x: 103, y: 42))
                path.addQuadCurve(to: .init(x: 140, y: 43), control: .init(x: 124, y: 36))
                path.addLine(to: .init(x: 146, y: 48))
                path.addLine(to: .init(x: 125, y: 46))
                path.addLine(to: .init(x: 108, y: 49))
                path.closeSubpath()
            }
        }

        static var handlebar: Path {
            Path { path in
                path.move(to: .init(x: 105, y: 33))
                path.addLine(to: .init(x: 98, y: 18))
                path.addLine(to: .init(x: 108, y: 12))
                path.addLine(to: .init(x: 119, y: 13))
            }
        }

        static let handlebarStroke = StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)

        static var handguard: Path {
            Path { path in
                path.move(to: .init(x: 112, y: 10))
                path.addLine(to: .init(x: 123, y: 11))
                path.addLine(to: .init(x: 126, y: 15))
                path.addLine(to: .init(x: 115, y: 16))
                path.closeSubpath()
            }
        }

        static var frontPlate: Path {
            Path { path in
                path.move(to: .init(x: 101, y: 23))
                path.addLine(to: .init(x: 111, y: 21))
                path.addLine(to: .init(x: 115, y: 32))
                path.addLine(to: .init(x: 106, y: 35))
                path.closeSubpath()
            }
        }
    }
}
