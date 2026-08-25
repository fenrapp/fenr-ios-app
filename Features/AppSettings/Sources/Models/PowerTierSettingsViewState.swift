public struct PowerTierSettingsViewState: Equatable, Sendable {
    public let selection: AppSettingsSelectionViewState
    public let status: String
    public let evidence: String?
    public let isVerifyEnabled: Bool
    public let isVerifying: Bool

    public init(
        selection: AppSettingsSelectionViewState,
        status: String,
        evidence: String? = nil,
        isVerifyEnabled: Bool = false,
        isVerifying: Bool = false
    ) {
        self.selection = selection
        self.status = status
        self.evidence = evidence
        self.isVerifyEnabled = isVerifyEnabled
        self.isVerifying = isVerifying
    }
}
