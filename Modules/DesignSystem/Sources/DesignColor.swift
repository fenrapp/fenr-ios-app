import SwiftUI

public enum DesignColor {
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
    public static let surface = Color.primary.opacity(0.03)
    public static let groupedSurface = Color.primary.opacity(0.06)
    public static let elevatedSurface = Color.primary.opacity(0.1)
    public static let controlSurface = Color.primary.opacity(0.14)
    public static let border = Color.primary.opacity(0.18)
    public static let accent = Color.accentColor
    public static let positive = Color.green
    public static let warning = Color.orange
    public static let critical = Color.red
    public static let informational = Color.teal
    public static let inactive = Color.secondary.opacity(0.25)
}
