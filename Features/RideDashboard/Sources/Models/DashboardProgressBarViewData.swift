public enum DashboardProgressBarViewData: Equatable, Sendable {
    case hidden
    case speed(progress: Double)
    case energy(
        regenerationProgress: Double,
        consumptionProgress: Double,
        accessibilityLabel: String
    )

    public static let neutralEnergy = DashboardProgressBarViewData.energy(
        regenerationProgress: .zero,
        consumptionProgress: .zero,
        accessibilityLabel: rideDashboardLocalized(.rideDashboardPowerNeutralAccessibility)
    )
}
