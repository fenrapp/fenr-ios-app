import SwiftUI

public enum DesignColor {
    public static let primaryText = Color(.label)
    public static let secondaryText = Color(.secondaryLabel)
    public static let surface = Color(.systemBackground)
    public static let groupedSurface = Color(.systemGroupedBackground)
    public static let elevatedSurface = Color(.secondarySystemGroupedBackground)
    public static let controlSurface = Color(.tertiarySystemGroupedBackground)
    public static let disabledControl = Color(.tertiarySystemFill)
    public static let border = Color(.separator).opacity(0.45)
    public static let accent = Color.accentColor
    public static let positive = Color.green
    public static let warning = Color.orange
    public static let critical = Color.red
    public static let informational = Color.teal
    public static let inactive = Color.secondary.opacity(0.25)
}
