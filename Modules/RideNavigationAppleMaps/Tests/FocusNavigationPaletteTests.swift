import CoreImage
import RideNavigation
@testable import RideNavigationAppleMaps
import SwiftUI
import Testing

struct FocusNavigationPaletteTests {
    @Test("dark Focus palette preserves the existing monochrome levels")
    func darkPalette() {
        let palette = FocusNavigationPalette(colorScheme: .dark)

        #expect(palette.backgroundWhiteLevel == 0)
        #expect(palette.routeWhiteLevel == 1)
        #expect(palette.futureRouteWhiteLevel == 0.72)
        #expect(palette.completedRouteWhiteLevel == 0.35)
        #expect(palette.recordedRouteWhiteLevel == 0.7)
        #expect(palette.riderWhiteLevel == 1)
        #expect(palette.riderOutlineWhiteLevel == 0.35)
        #expect(palette.directionalIndicatorWhiteLevel == 1)
        #expect(palette.neutralMarkerWhiteLevel == 0.55)
    }

    @Test("light Focus palette inverts every monochrome level")
    func lightPalette() {
        let dark = FocusNavigationPalette(colorScheme: .dark)
        let light = FocusNavigationPalette(colorScheme: .light)

        #expect(light.backgroundWhiteLevel == 1 - dark.backgroundWhiteLevel)
        #expect(light.routeWhiteLevel == 1 - dark.routeWhiteLevel)
        #expect(light.futureRouteWhiteLevel == 1 - dark.futureRouteWhiteLevel)
        #expect(light.completedRouteWhiteLevel == 1 - dark.completedRouteWhiteLevel)
        #expect(light.recordedRouteWhiteLevel == 1 - dark.recordedRouteWhiteLevel)
        #expect(light.riderWhiteLevel == 1 - dark.riderWhiteLevel)
        #expect(light.riderOutlineWhiteLevel == 1 - dark.riderOutlineWhiteLevel)
        #expect(light.directionalIndicatorWhiteLevel == 1 - dark.directionalIndicatorWhiteLevel)
        #expect(light.neutralMarkerWhiteLevel == 1 - dark.neutralMarkerWhiteLevel)
    }

    @MainActor
    @Test("Focus map surface redraws when the system appearance changes")
    func mapSurfaceFollowsColorScheme() throws {
        let darkPixel = try renderedCenterPixel(colorScheme: .dark)
        let lightPixel = try renderedCenterPixel(colorScheme: .light)

        #expect(darkPixel.red < 8)
        #expect(darkPixel.green < 8)
        #expect(darkPixel.blue < 8)
        #expect(lightPixel.red > 247)
        #expect(lightPixel.green > 247)
        #expect(lightPixel.blue > 247)
    }

    @MainActor
    private func renderedCenterPixel(colorScheme: ColorScheme) throws -> Pixel {
        let view = FocusNavigationMapView(
            scene: NavigationMapScene(displayStyle: .focus),
            renderer: FocusNavigationRenderer(pathCache: FocusNavigationPathCache()),
            onIntent: { _ in },
            onInteraction: {}
        )
        .environment(\.colorScheme, colorScheme)
        .frame(width: Constants.renderSize, height: Constants.renderSize)
        let imageRenderer = ImageRenderer(content: view)
        imageRenderer.scale = 1
        let image = try #require(imageRenderer.uiImage)
        let inputImage = try #require(CIImage(image: image))
        var bytes = [UInt8](repeating: .zero, count: Constants.bytesPerPixel)
        CIContext().render(
            inputImage,
            toBitmap: &bytes,
            rowBytes: Constants.bytesPerPixel,
            bounds: Constants.sampleBounds,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return Pixel(red: bytes[0], green: bytes[1], blue: bytes[2])
    }

    private struct Pixel {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
    }

    private enum Constants {
        static let renderSize: CGFloat = 40
        static let bytesPerPixel = 4
        static let sampleBounds = CGRect(x: 20, y: 20, width: 1, height: 1)
    }
}
