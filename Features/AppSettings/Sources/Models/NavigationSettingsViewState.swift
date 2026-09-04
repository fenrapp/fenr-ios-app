import Foundation

public struct NavigationSettingsViewState: Equatable, Sendable {
    public let showsGuidanceInFocus: Bool
    public let showsCompassRing: Bool
    public let showsRoadsInFocus: Bool
    public let lineStyles: [NavigationLineStyleViewData]

    public init(
        showsGuidanceInFocus: Bool = false,
        showsCompassRing: Bool = false,
        showsRoadsInFocus: Bool = false,
        lineStyles: [NavigationLineStyleViewData] = []
    ) {
        self.showsGuidanceInFocus = showsGuidanceInFocus
        self.showsCompassRing = showsCompassRing
        self.showsRoadsInFocus = showsRoadsInFocus
        self.lineStyles = lineStyles
    }
}

public struct NavigationLineStyleViewData: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: LocalizedStringResource
    public let color: NavigationColorComponents
    public let thickness: AppSettingsSelectionViewState

    public init(
        id: String,
        title: LocalizedStringResource,
        color: NavigationColorComponents,
        thickness: AppSettingsSelectionViewState
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.thickness = thickness
    }
}

public struct NavigationColorComponents: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}
