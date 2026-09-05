import DesignSystem
import SwiftUI

struct DashboardRearMotorcycleSymbol: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(
                x: size.width / Artwork.viewBoxSize.width,
                y: size.height / Artwork.viewBoxSize.height
            )
            context.stroke(Artwork.handlebar, with: .foreground, style: Artwork.handlebarStroke)
            context.fill(Artwork.handguards, with: .foreground)
            context.fill(Artwork.sidePanels, with: .foreground)
            context.stroke(Artwork.swingarm, with: .foreground, style: Artwork.swingarmStroke)
            context.stroke(Artwork.rearTire, with: .foreground, style: Artwork.rearTireStroke)
            context.stroke(Artwork.tread, with: .foreground, style: Artwork.treadStroke)
            context.fill(Artwork.tail, with: .foreground)
            context.blendMode = .destinationOut
            context.fill(Artwork.seatInset, with: .color(.white))
            context.blendMode = .normal
            context.fill(Artwork.tailAccent, with: .color(DesignColor.informational))
        }
        .aspectRatio(Artwork.viewBoxSize.width / Artwork.viewBoxSize.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private enum Artwork {
        static let viewBoxSize = CGSize(width: 112, height: 128)

        static var handlebar: Path {
            Path { path in
                path.move(to: .init(x: 15, y: 22))
                path.addLine(to: .init(x: 31, y: 15))
                path.addLine(to: .init(x: 43, y: 18))
                path.addLine(to: .init(x: 48, y: 24))
                path.addLine(to: .init(x: 64, y: 24))
                path.addLine(to: .init(x: 69, y: 18))
                path.addLine(to: .init(x: 81, y: 15))
                path.addLine(to: .init(x: 97, y: 22))
            }
        }

        static let handlebarStroke = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)

        static var handguards: Path {
            Path { path in
                path.move(to: .init(x: 5, y: 19))
                path.addLine(to: .init(x: 16, y: 16))
                path.addLine(to: .init(x: 27, y: 22))
                path.addLine(to: .init(x: 22, y: 28))
                path.addLine(to: .init(x: 10, y: 27))
                path.closeSubpath()
                path.move(to: .init(x: 107, y: 19))
                path.addLine(to: .init(x: 96, y: 16))
                path.addLine(to: .init(x: 85, y: 22))
                path.addLine(to: .init(x: 90, y: 28))
                path.addLine(to: .init(x: 102, y: 27))
                path.closeSubpath()
            }
        }

        static var sidePanels: Path {
            Path { path in
                path.move(to: .init(x: 29, y: 34))
                path.addLine(to: .init(x: 42, y: 29))
                path.addLine(to: .init(x: 43, y: 49))
                path.addLine(to: .init(x: 38, y: 66))
                path.addLine(to: .init(x: 31, y: 58))
                path.addLine(to: .init(x: 26, y: 41))
                path.closeSubpath()
                path.move(to: .init(x: 83, y: 34))
                path.addLine(to: .init(x: 70, y: 29))
                path.addLine(to: .init(x: 69, y: 49))
                path.addLine(to: .init(x: 74, y: 66))
                path.addLine(to: .init(x: 81, y: 58))
                path.addLine(to: .init(x: 86, y: 41))
                path.closeSubpath()
            }
        }

        static var swingarm: Path {
            Path { path in
                path.move(to: .init(x: 38, y: 65))
                path.addLine(to: .init(x: 43, y: 99))
                path.move(to: .init(x: 74, y: 65))
                path.addLine(to: .init(x: 69, y: 99))
            }
        }

        static let swingarmStroke = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)

        static var rearTire: Path {
            Path(roundedRect: .init(x: 46, y: 68, width: 20, height: 53), cornerRadius: 8)
        }

        static let rearTireStroke = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)

        static var tread: Path {
            Path { path in
                path.move(to: .init(x: 48, y: 79))
                path.addLine(to: .init(x: 51, y: 79))
                path.move(to: .init(x: 61, y: 79))
                path.addLine(to: .init(x: 64, y: 79))
                path.move(to: .init(x: 48, y: 92))
                path.addLine(to: .init(x: 51, y: 92))
                path.move(to: .init(x: 61, y: 92))
                path.addLine(to: .init(x: 64, y: 92))
                path.move(to: .init(x: 48, y: 105))
                path.addLine(to: .init(x: 51, y: 105))
                path.move(to: .init(x: 61, y: 105))
                path.addLine(to: .init(x: 64, y: 105))
            }
        }

        static let treadStroke = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)

        static var tail: Path {
            Path { path in
                path.move(to: .init(x: 49, y: 28))
                path.addLine(to: .init(x: 63, y: 28))
                path.addLine(to: .init(x: 66, y: 44))
                path.addLine(to: .init(x: 70, y: 51))
                path.addLine(to: .init(x: 66, y: 65))
                path.addLine(to: .init(x: 62, y: 74))
                path.addLine(to: .init(x: 50, y: 74))
                path.addLine(to: .init(x: 46, y: 65))
                path.addLine(to: .init(x: 42, y: 51))
                path.addLine(to: .init(x: 46, y: 44))
                path.closeSubpath()
            }
        }

        static var seatInset: Path {
            Path { path in
                path.move(to: .init(x: 50, y: 34))
                path.addLine(to: .init(x: 62, y: 34))
                path.addLine(to: .init(x: 64, y: 46))
                path.addLine(to: .init(x: 48, y: 46))
                path.closeSubpath()
            }
        }

        static var tailAccent: Path {
            Path { path in
                path.move(to: .init(x: 49, y: 53))
                path.addLine(to: .init(x: 63, y: 53))
                path.addLine(to: .init(x: 61, y: 58))
                path.addLine(to: .init(x: 51, y: 58))
                path.closeSubpath()
            }
        }
    }
}
