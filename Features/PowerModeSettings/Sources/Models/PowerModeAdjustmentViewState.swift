import Foundation

public struct PowerModeAdjustmentViewState: Equatable, Identifiable, Sendable {
    public let id: PowerModeAdjustmentID
    public let title: String
    public let value: Double?
    public let valueText: String
    public let unit: String
    public let minimum: Double
    public let maximum: Double
    public let step: Double
    public let isEnabled: Bool
    public let localeIdentifier: String
    public let feedback: PowerModeControlFeedback

    public init(
        id: PowerModeAdjustmentID,
        title: String,
        value: Double?,
        valueText: String,
        unit: String,
        minimum: Double,
        maximum: Double,
        step: Double,
        isEnabled: Bool,
        localeIdentifier: String,
        feedback: PowerModeControlFeedback = .idle
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.valueText = valueText
        self.unit = unit
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.isEnabled = isEnabled
        self.localeIdentifier = localeIdentifier
        self.feedback = feedback
    }
}
